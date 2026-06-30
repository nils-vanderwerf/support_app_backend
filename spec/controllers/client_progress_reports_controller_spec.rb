require 'rails_helper'

RSpec.describe 'ClientProgressReportsController', type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Alice', last_name: 'Smith', email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved') }

  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }

  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending', role: 'support_worker') }
  let(:pending_worker) { SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending', email: 'pending@test.com', phone: '0411111111', location: 'Melbourne', status: 'pending') }

  let(:ai_response) do
    { 'content' => [{ 'type' => 'text', 'text' => '## Overall Progress\nGood progress.' }] }
  end

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'POST /api/client_progress_reports' do
    context 'when not logged in' do
      it 'returns forbidden' do
        post '/api/client_progress_reports', params: { client_id: 1 }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a client' do
      before { client; login_as(client_user) }

      it 'returns forbidden' do
        post '/api/client_progress_reports', params: { client_id: client.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a pending support worker' do
      before { pending_worker; login_as(pending_sw_user) }

      it 'returns forbidden' do
        post '/api/client_progress_reports', params: { client_id: client.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker' do
      before { support_worker; login_as(sw_user) }

      it 'returns 404 for an unknown client' do
        post '/api/client_progress_reports', params: { client_id: 99999 }
        expect(response).to have_http_status(:not_found)
      end

      context 'without an approved appointment for the client' do
        it 'returns forbidden' do
          client
          post '/api/client_progress_reports', params: { client_id: client.id }
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'with an approved appointment for the client' do
        let!(:appointment) { Appointment.create!(client: client, support_worker: support_worker, date: 1.week.ago, status: 'approved') }

        it 'returns a friendly message when no visit reports exist' do
          post '/api/client_progress_reports', params: { client_id: client.id }
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['report_count']).to eq(0)
          expect(body['summary']).to be_nil
        end

        it 'returns an AI-generated summary when visit reports exist' do
          VisitReport.create!(
            appointment: appointment,
            user_id: sw_user.id,
            client_id: client.id,
            date: 1.week.ago,
            activities: 'Helped with meals',
            observations: 'Client was engaged',
            follow_up_actions: 'Follow up on medication'
          )
          allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(ai_response)
          post '/api/client_progress_reports', params: { client_id: client.id }
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['report_count']).to eq(1)
          expect(body['summary']).to include('Overall Progress')
        end
      end
    end
  end
end
