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
      age: 30,
      location: 'Sydney',
      bio: 'Experienced carer',
      experience: '5 years in disability support'
    )
  end

  describe "GET /api/support_workers" do
    before { support_worker }

    it 'returns all support workers' do
      get api_support_workers_path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).count).to eq(1)
    end

    it 'returns support worker attributes' do
      get api_support_workers_path
      json = JSON.parse(response.body)
      expect(json.first['first_name']).to eq('Bob')
      expect(json.first['last_name']).to eq('Brown')
    end
  end

  describe "GET /api/support_workers/:id" do
    it 'returns the requested support worker' do
      get api_support_worker_path(support_worker)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(support_worker.id)
      expect(json['first_name']).to eq('Bob')
    end
  end
end
