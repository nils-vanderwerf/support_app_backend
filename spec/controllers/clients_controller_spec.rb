require 'rails_helper'

RSpec.describe "ClientsController", type: :request do
  let(:client_user) { User.create!(email: 'c@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:other_user) { User.create!(email: 'other@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith') }
  let(:other_client) { Client.create!(user: other_user, first_name: 'Alice', last_name: 'Smith') }
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown', email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved') }

  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending') }
  let(:pending_worker) { SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending', email: 'pending@test.com', phone: '0411111111', location: 'Melbourne', status: 'pending') }

  describe "GET /api/clients" do
    context 'when unauthenticated' do
      it 'returns forbidden' do
        get api_clients_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a client' do
      before { client; post api_login_path, params: { email: client_user.email, password: 'password123' } }

      it 'returns forbidden' do
        get api_clients_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker' do
      before { client; support_worker; post api_login_path, params: { email: sw_user.email, password: 'password123' } }

      it 'returns all clients' do
        get api_clients_path
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).count).to eq(1)
      end

      it 'returns only safe fields' do
        get api_clients_path
        json = JSON.parse(response.body).first
        expect(json.keys).to match_array(%w[id first_name last_name age location health_conditions])
        expect(json.keys).not_to include('phone', 'email', 'medication', 'allergies')
      end
    end

    context 'when logged in as a pending support worker' do
      before { pending_worker; post api_login_path, params: { email: pending_sw_user.email, password: 'password123' } }

      it 'returns forbidden' do
        get api_clients_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/clients/:id" do
    context 'when unauthenticated' do
      it 'returns forbidden' do
        get api_client_path(client)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a client' do
      before { client; post api_login_path, params: { email: client_user.email, password: 'password123' } }

      it 'returns their own record' do
        get api_client_path(client)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['id']).to eq(client.id)
      end

      it 'returns forbidden for another client' do
        other_client
        get api_client_path(other_client)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker without a confirmed appointment' do
      before { client; support_worker; post api_login_path, params: { email: sw_user.email, password: 'password123' } }

      it 'returns limited fields only' do
        get api_client_path(client)
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.keys).to match_array(%w[id first_name health_conditions last_name location bio has_approved_appointment])
        expect(json.keys).not_to include('phone', 'email', 'medication', 'allergies')
      end

      it 'returns has_approved_appointment: false' do
        get api_client_path(client)
        expect(JSON.parse(response.body)['has_approved_appointment']).to be false
      end
    end

    context 'when logged in as an approved support worker with a confirmed appointment' do
      before do
        client
        support_worker
        Appointment.create!(client: client, support_worker: support_worker, date: '2026-05-01', status: 'approved')
        post api_login_path, params: { email: sw_user.email, password: 'password123' }
      end

      it 'returns the full client record' do
        get api_client_path(client)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['id']).to eq(client.id)
      end

      it 'returns has_approved_appointment: true' do
        get api_client_path(client)
        expect(JSON.parse(response.body)['has_approved_appointment']).to be true
      end
    end

    context 'when logged in as a pending support worker' do
      before { client; pending_worker; post api_login_path, params: { email: pending_sw_user.email, password: 'password123' } }

      it 'returns forbidden' do
        get api_client_path(client)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/clients/:id/visit_reports" do
    let(:appointment) { Appointment.create!(client: client, support_worker: support_worker, date: '2026-05-01', status: 'approved') }
    let!(:visit_report) do
      VisitReport.create!(
        appointment: appointment,
        support_worker_id: support_worker.id,
        client_id: client.id,
        date: '2026-05-01',
        activities: 'Assisted with meal prep',
        observations: 'Client was engaged',
        follow_up_actions: 'Follow up next week'
      )
    end

    context 'when not logged in' do
      it 'returns forbidden' do
        get visit_reports_api_client_path(client)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as the client' do
      before { client; appointment; post api_login_path, params: { email: client_user.email, password: 'password123' } }

      it 'returns all visit reports for the client' do
        get visit_reports_api_client_path(client)
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.length).to eq(1)
        expect(body.first['activities']).to eq('Assisted with meal prep')
      end

      it 'includes support_worker in the response' do
        get visit_reports_api_client_path(client)
        body = JSON.parse(response.body)
        expect(body.first['support_worker']).to include('first_name' => 'Bob', 'last_name' => 'Brown')
      end
    end

    context 'when logged in as an approved support worker without an approved appointment' do
      let(:other_sw_user) { User.create!(email: 'other_sw@test.com', password: 'password123', first_name: 'Carol', last_name: 'Clark') }
      let!(:other_worker) { SupportWorker.create!(user: other_sw_user, first_name: 'Carol', last_name: 'Clark', email: 'other_sw@test.com', phone: '0422222222', location: 'Sydney', status: 'approved') }

      before { client; other_worker; post api_login_path, params: { email: other_sw_user.email, password: 'password123' } }

      it 'returns forbidden' do
        get visit_reports_api_client_path(client)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker with an approved appointment' do
      before { client; support_worker; appointment; post api_login_path, params: { email: sw_user.email, password: 'password123' } }

      it 'returns their own visit reports for the client' do
        get visit_reports_api_client_path(client)
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.length).to eq(1)
        expect(body.first['activities']).to eq('Assisted with meal prep')
      end

      it 'includes appointment in the response' do
        get visit_reports_api_client_path(client)
        body = JSON.parse(response.body)
        expect(body.first['appointment']).to include('id' => appointment.id)
      end
    end

    context 'when logged in as a pending support worker' do
      before { client; pending_worker; post api_login_path, params: { email: pending_sw_user.email, password: 'password123' } }

      it 'returns forbidden' do
        get visit_reports_api_client_path(client)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
