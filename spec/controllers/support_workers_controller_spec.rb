require 'rails_helper'

RSpec.describe "SupportWorkersController", type: :request do
  let(:user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) do
    SupportWorker.create!(
      user: user,
      first_name: 'Bob',
      last_name: 'Brown',
      email: 'sw@test.com',
      phone: '0400000000',
      location: 'Sydney',
      bio: 'Experienced carer',
      experience: 5,
      status: 'approved'
    )
  end

  let(:other_user) { User.create!(email: 'other_sw@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith') }
  let(:other_support_worker) do
    SupportWorker.create!(
      user: other_user,
      first_name: 'Alice',
      last_name: 'Smith',
      email: 'other_sw@test.com',
      phone: '0411111111',
      location: 'Melbourne',
      bio: 'Caring professional',
      experience: 3,
      status: 'approved'
    )
  end

  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }

  describe "GET /api/support_workers" do
    before { support_worker }

    context 'when not logged in' do
      it 'returns forbidden' do
        get api_support_workers_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when a support worker is logged in' do
      before do
        support_worker
        post api_login_path, params: { email: user.email, password: 'password123' }
      end

      it 'returns forbidden' do
        get api_support_workers_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when a client is logged in' do
      before do
        client
        support_worker
        post api_login_path, params: { email: client_user.email, password: 'password123' }
      end

      it 'returns the support worker list' do
        get api_support_workers_path
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).count).to eq(1)
      end
    end
  end

  describe "GET /api/support_workers/:id" do
    context 'when a client is logged in' do
      before do
        client
        post api_login_path, params: { email: client_user.email, password: 'password123' }
      end

      it 'returns the requested support worker' do
        get api_support_worker_path(support_worker)
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(support_worker.id)
        expect(json['first_name']).to eq('Bob')
      end
    end

    context 'when a support worker views their own profile' do
      before { post api_login_path, params: { email: user.email, password: 'password123' } }

      it 'returns ok' do
        get api_support_worker_path(support_worker)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when a support worker views another support worker profile' do
      before do
        other_support_worker
        post api_login_path, params: { email: user.email, password: 'password123' }
      end

      it 'returns forbidden' do
        get api_support_worker_path(other_support_worker)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/support_workers/:id" do
    before { post api_login_path, params: { email: user.email, password: 'password123' } }

    context 'when the support worker updates their own profile' do
      it 'updates permitted fields' do
        patch api_support_worker_path(support_worker), params: {
          support_worker: { bio: 'Updated bio', experience: 7, location: 'Brisbane' }
        }
        expect(response).to have_http_status(:ok)
        expect(support_worker.reload.bio).to eq('Updated bio')
        expect(support_worker.reload.experience).to eq(7)
      end

      it 'updates qualification and institution' do
        patch api_support_worker_path(support_worker), params: {
          support_worker: { qualification: "Bachelor's Degree", institution: 'University of Sydney' }
        }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['qualification']).to eq("Bachelor's Degree")
        expect(json['institution']).to eq('University of Sydney')
      end
    end

    context 'when a different support worker tries to update the profile' do
      before do
        other_support_worker
        post api_login_path, params: { email: other_user.email, password: 'password123' }
      end

      it 'returns forbidden' do
        patch api_support_worker_path(support_worker), params: {
          support_worker: { bio: 'Hacked bio' }
        }
        expect(response).to have_http_status(:forbidden)
        expect(support_worker.reload.bio).to eq('Experienced carer')
      end
    end

    context 'when a client tries to update a support worker profile' do
      before do
        client
        post api_login_path, params: { email: client_user.email, password: 'password123' }
      end

      it 'returns forbidden' do
        patch api_support_worker_path(support_worker), params: {
          support_worker: { bio: 'Hacked bio' }
        }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
