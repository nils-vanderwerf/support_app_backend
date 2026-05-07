require 'rails_helper'

RSpec.describe "ClientsController", type: :request do
  let(:client_user) { User.create!(email: 'c@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:other_user) { User.create!(email: 'other@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith') }
  let(:other_client) { Client.create!(user: other_user, first_name: 'Alice', last_name: 'Smith') }
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown', email: 'sw@test.com', phone: '0400000000', age: 30, location: 'Sydney', status: 'approved') }

  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending') }
  let(:pending_worker) { SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending', email: 'pending@test.com', phone: '0411111111', age: 25, location: 'Melbourne', status: 'pending') }

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

    context 'when logged in as an approved support worker' do
      before { client; support_worker; post api_login_path, params: { email: sw_user.email, password: 'password123' } }

      it 'returns any client record' do
        get api_client_path(client)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['id']).to eq(client.id)
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
end
