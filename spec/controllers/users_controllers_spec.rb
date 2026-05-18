require 'rails_helper'

RSpec.describe "POST /api/users", type: :request do
  let(:valid_client_params) do
    {
      user: { email: 'test_client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe', middle_name: '' },
      role: 'client',
      client: { first_name: 'Jane', last_name: 'Doe', age: 30, gender: 'Female', phone: '0400000000', location: 'Sydney', bio: 'Test bio' }
    }
  end
   let(:valid_support_worker_params) do
      {
        user: { email: 'test_sw@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe', middle_name: '' },
        role: 'support_worker',
        support_worker: { first_name: 'Jane', last_name: 'Doe', email: 'test_sw@test.com', age: 30, gender: 'Non Binary', phone: '0410000000', location: 'Sydney', bio: 'Test bio' }
      }
  end
  let(:invalid_client_params) do
    {
      user: { email: '', password: 'password123', first_name: 'Jane', last_name: 'Doe' },
      role: 'client',
      client: { age: 30 }
    }
  end
  let(:invalid_support_worker_params) do
    {
      user: { email: 'billy.browne@gmail.com', password: 'password123', first_name: '', last_name: 'Brown' },
      role: 'support_worker',
      support_worker: { age: 55 }
    }
  end
  let(:invalid_role_params) do
    {
      user: { email: 'billy.browne@gmail.com', password: 'password123', first_name: '', last_name: 'Brown' },
      role: 'invalid_role',
      support_worker: { age: 55 }
    }
  end
  it "creates a user and client" do
    post api_users_path, params: valid_client_params
    expect(response).to have_http_status(:created)
    expect(User.count).to eq(1)
    expect(Client.count).to eq(1)
  end
  it "creates a user and support worker" do
    post api_users_path, params: valid_support_worker_params, headers: { 'X-CSRF-Token' => 'test' }
    expect(response).to have_http_status(:created)
    expect(User.count).to eq(1)
    expect(SupportWorker.count).to eq(1)
  end
  it "does not create a user or a client if client creation fails" do
    post api_users_path, params: invalid_client_params
    expect(User.count).to eq(0)
    expect(Client.count).to eq(0)
  end
  it "does not create a user or a support_worker if support worker creation fails" do
    post api_users_path, params: invalid_support_worker_params
    expect(User.count).to eq(0)
    expect(SupportWorker.count).to eq(0)
  end
  it "returns an error for an invalid user role" do
    post api_users_path, params: invalid_role_params
    expect(response).to have_http_status(:unprocessable_entity)
  end
  it "returns bad request if user params are missing" do
    post api_users_path, params: { role: 'client', client: { age: 30 } }
    expect(response).to have_http_status(:bad_request)
    expect(response).to have_http_status(:bad_request)
  end
end
