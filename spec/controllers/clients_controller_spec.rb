require 'rails_helper'

RSpec.describe "ClientsController", type: :request do
  let(:user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: user, first_name: 'Jane', last_name: 'Doe') }

  describe "GET /api/clients" do
    before { client }

    it 'returns all clients' do
      get api_clients_path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).count).to eq(1)
    end

    it 'returns client attributes' do
      get api_clients_path
      json = JSON.parse(response.body)
      expect(json.first['first_name']).to eq('Jane')
      expect(json.first['last_name']).to eq('Doe')
    end
  end

  describe "GET /api/clients/:id" do
    it 'returns the requested client' do
      get api_client_path(client)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(client.id)
      expect(json['first_name']).to eq('Jane')
    end
  end
end
