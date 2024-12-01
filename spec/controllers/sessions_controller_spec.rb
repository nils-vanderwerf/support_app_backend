require 'rails_helper'

RSpec.describe "SessionsController", type: :request do
  let(:valid_user) { User.create!(email: 'test@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }

  describe "POST /api/login" do
    context "when credentials are valid" do
      it 'returns the user, client and support worker' do
        post api_login_path, params: { email: valid_user.email, password: 'password123' }
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json).to have_key("user")
        expect(json).to have_key("client")
        expect(json).to have_key("support_worker")
      end
    end

    context "when email is not found" do
      it 'returns unauthorized' do
        post api_login_path, params: { email: 'wrong@test.com', password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when password is incorrect" do
      it 'returns unauthorized' do
        post api_login_path, params: { email: valid_user.email, password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/user" do
    context "when a user is logged in" do
      before do
        post api_login_path, params: { email: valid_user.email, password: 'password123' }
      end

      it 'returns a json object with the user' do
        get api_user_path
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json).to have_key("user")
      end
    end

    context "when no user is logged in" do
      it 'returns unauthorized' do
        get api_user_path
        json = JSON.parse(response.body)
        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq("You're not authorized to view this page")
      end
    end
  end
end
