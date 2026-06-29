require 'rails_helper'

RSpec.describe 'CronController', type: :request do
  let(:secret) { 'test-cron-secret' }

  before { allow(ENV).to receive(:fetch).and_call_original }

  describe 'POST /api/cron/credential_expiry' do
    context 'with no Authorization header' do
      it 'returns unauthorized' do
        post '/api/cron/credential_expiry'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a wrong secret' do
      it 'returns unauthorized' do
        post '/api/cron/credential_expiry', headers: { 'Authorization' => 'Bearer wrong-secret' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with the correct secret' do
      before { allow(ENV).to receive(:[]).with('CRON_SECRET').and_return(secret) }

      it 'runs the job and returns ok' do
        expect(CredentialExpiryJob).to receive(:perform_now)
        post '/api/cron/credential_expiry', headers: { 'Authorization' => "Bearer #{secret}" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['ok']).to be true
      end
    end
  end
end
