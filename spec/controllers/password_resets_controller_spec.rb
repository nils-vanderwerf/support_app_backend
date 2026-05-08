require 'rails_helper'

RSpec.describe 'PasswordResetsController', type: :request do
  let!(:user) do
    User.create!(email: 'test@example.com', password: 'password123',
                 first_name: 'Jane', last_name: 'Doe')
  end

  describe 'POST /api/password_resets' do
    it 'returns 200 for a known email and sends an email' do
      expect {
        post '/api/password_resets', params: { email: 'test@example.com' }
      }.to change(ActionMailer::Base.deliveries, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 even for an unknown email (no enumeration)' do
      expect {
        post '/api/password_resets', params: { email: 'nobody@example.com' }
      }.not_to change(ActionMailer::Base.deliveries, :count)
      expect(response).to have_http_status(:ok)
    end

    it 'sets reset_password_token and reset_password_sent_at on the user' do
      post '/api/password_resets', params: { email: 'test@example.com' }
      user.reload
      expect(user.reset_password_token).not_to be_nil
      expect(user.reset_password_sent_at).not_to be_nil
    end
  end

  describe 'PATCH /api/password_resets/:token' do
    let(:raw_token) { 'validtoken123' }
    before do
      user.update!(
        reset_password_token: Digest::SHA256.hexdigest(raw_token),
        reset_password_sent_at: Time.current
      )
    end

    it 'updates the password and clears the token' do
      patch "/api/password_resets/#{raw_token}", params: { password: 'newpassword99' }
      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.reset_password_token).to be_nil
      expect(user.valid_password?('newpassword99')).to be true
    end

    it 'rejects an expired token' do
      user.update!(reset_password_sent_at: 3.hours.ago)
      patch "/api/password_resets/#{raw_token}", params: { password: 'newpassword99' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an invalid token' do
      patch '/api/password_resets/badtoken', params: { password: 'newpassword99' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
