require 'rails_helper'

RSpec.describe "PasswordResetsController", type: :request do
  let!(:user) { User.create!(email: 'test@example.com', password: 'oldpassword', first_name: 'Jane', last_name: 'Doe') }

  describe "POST /api/password_resets/request" do
    context 'with a registered email' do
      it 'returns a success message and sets a reset token' do
        post api_password_resets_request_path, params: { email: 'test@example.com' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to include('reset link')
        expect(user.reload.reset_password_token).not_to be_nil
        expect(user.reload.reset_password_sent_at).not_to be_nil
      end
    end

    context 'with an unregistered email' do
      it 'returns the same success message to prevent email enumeration' do
        post api_password_resets_request_path, params: { email: 'nobody@example.com' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to include('reset link')
      end
    end

    context 'with a blank email' do
      it 'returns the same success message' do
        post api_password_resets_request_path, params: { email: '' }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /api/password_resets/reset" do
    let(:raw_token) do
      raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
      user.update!(reset_password_token: hashed, reset_password_sent_at: Time.now.utc)
      raw
    end

    context 'with a valid token and new password' do
      it 'updates the password and returns success' do
        post api_password_resets_reset_path, params: { token: raw_token, password: 'newpassword123' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to include('updated')
        expect(user.reload.valid_password?('newpassword123')).to be true
      end
    end

    context 'with an invalid token' do
      it 'returns unprocessable_entity' do
        post api_password_resets_reset_path, params: { token: 'badtoken', password: 'newpassword123' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with an expired token (older than Devise reset_password_within)' do
      it 'returns unprocessable_entity' do
        raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
        user.update!(reset_password_token: hashed, reset_password_sent_at: 7.hours.ago)
        post api_password_resets_reset_path, params: { token: raw, password: 'newpassword123' }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
