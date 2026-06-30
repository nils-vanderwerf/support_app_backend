require 'rails_helper'

RSpec.describe 'ReviewsController', type: :request do
  let(:client_user) { create(:user) }
  let(:client) { create(:client, user: client_user) }

  let(:sw_user) { create(:user, :as_support_worker) }
  let(:support_worker) { create(:support_worker, user: sw_user) }

  let(:other_client_user) { create(:user) }
  let(:other_client) { create(:client, user: other_client_user) }

  let(:past_approved_appointment) do
    create(:appointment, :past, client: client, support_worker: support_worker, status: 'approved')
  end

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'GET /api/support_workers/:id/reviews' do
    let!(:review) do
      create(:review, client: client, support_worker: support_worker,
             appointment: past_approved_appointment, rating: 4, comment: 'Very helpful')
    end

    it 'returns reviews for the support worker' do
      get api_support_worker_reviews_path(support_worker)
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first['rating']).to eq(4)
      expect(body.first['comment']).to eq('Very helpful')
      expect(body.first['appointment_id']).to eq(past_approved_appointment.id)
    end

    it 'includes client name in each review' do
      get api_support_worker_reviews_path(support_worker)
      body = JSON.parse(response.body)
      expect(body.first['client']).to include('id', 'first_name', 'last_name')
    end

    it 'returns an empty array when the worker has no reviews' do
      other_worker = create(:support_worker)
      get api_support_worker_reviews_path(other_worker)
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe 'POST /api/reviews' do
    context 'as the client who owns the appointment' do
      before do
        client
        login_as(client_user)
      end

      it 'creates a review and returns 201' do
        post api_reviews_path, params: {
          appointment_id: past_approved_appointment.id,
          rating: 5,
          comment: 'Excellent!'
        }
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['rating']).to eq(5)
        expect(body['comment']).to eq('Excellent!')
        expect(body['appointment_id']).to eq(past_approved_appointment.id)
      end

      it 'creates a review without a comment' do
        post api_reviews_path, params: {
          appointment_id: past_approved_appointment.id,
          rating: 3
        }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['comment']).to be_nil
      end

      it 'returns 422 for an invalid rating' do
        post api_reviews_path, params: {
          appointment_id: past_approved_appointment.id,
          rating: 6
        }
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body['errors']).to be_present
      end

      it 'returns 422 when the appointment already has a review' do
        create(:review, client: client, support_worker: support_worker,
               appointment: past_approved_appointment)
        post api_reviews_path, params: {
          appointment_id: past_approved_appointment.id,
          rating: 4
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 404 when the appointment does not exist' do
        post api_reviews_path, params: { appointment_id: 99999, rating: 5 }
        expect(response).to have_http_status(:not_found)
      end

      it 'sends a notification email to the support worker' do
        expect {
          post api_reviews_path, params: {
            appointment_id: past_approved_appointment.id,
            rating: 5,
            comment: 'Great!'
          }
        }.to have_enqueued_mail(ReviewMailer, :new_review)
      end
    end

    context 'as a different client' do
      before do
        other_client
        login_as(other_client_user)
      end

      it 'returns 403 when the appointment belongs to another client' do
        post api_reviews_path, params: {
          appointment_id: past_approved_appointment.id,
          rating: 5
        }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as a support worker' do
      before { login_as(sw_user) }

      it 'returns 403' do
        post api_reviews_path, params: {
          appointment_id: past_approved_appointment.id,
          rating: 5
        }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not logged in' do
      it 'returns 403' do
        post api_reviews_path, params: { appointment_id: past_approved_appointment.id, rating: 5 }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/reviews/:id' do
    let!(:review) do
      create(:review, client: client, support_worker: support_worker,
             appointment: past_approved_appointment, rating: 3, comment: 'Good')
    end

    context 'as the review owner' do
      before do
        client
        login_as(client_user)
      end

      it 'updates rating and comment and returns 200' do
        patch api_review_path(review), params: { rating: 5, comment: 'Excellent!' }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['rating']).to eq(5)
        expect(body['comment']).to eq('Excellent!')
      end

      it 'persists the changes' do
        patch api_review_path(review), params: { rating: 4, comment: 'Updated' }
        expect(review.reload.rating).to eq(4)
        expect(review.reload.comment).to eq('Updated')
      end

      it 'returns 422 for an invalid rating' do
        patch api_review_path(review), params: { rating: 0 }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as a different client' do
      before do
        other_client
        login_as(other_client_user)
      end

      it 'returns 403' do
        patch api_review_path(review), params: { rating: 1, comment: 'Hacked' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not logged in' do
      it 'returns 403' do
        patch api_review_path(review), params: { rating: 5 }
        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'returns 404 for a non-existent review' do
      client
      login_as(client_user)
      patch api_review_path(id: 99999), params: { rating: 5 }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/reviews/:id' do
    let!(:review) do
      create(:review, client: client, support_worker: support_worker,
             appointment: past_approved_appointment, rating: 4)
    end

    context 'as the review owner' do
      before do
        client
        login_as(client_user)
      end

      it 'deletes the review and returns 204' do
        delete api_review_path(review)
        expect(response).to have_http_status(:no_content)
        expect(Review.find_by(id: review.id)).to be_nil
      end
    end

    context 'as a different client' do
      before do
        other_client
        login_as(other_client_user)
      end

      it 'returns 403' do
        delete api_review_path(review)
        expect(response).to have_http_status(:forbidden)
        expect(Review.find_by(id: review.id)).to be_present
      end
    end

    context 'when not logged in' do
      it 'returns 403' do
        delete api_review_path(review)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'returns 404 for a non-existent review' do
      client
      login_as(client_user)
      delete api_review_path(id: 99999)
      expect(response).to have_http_status(:not_found)
    end
  end
end
