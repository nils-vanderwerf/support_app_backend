require 'rails_helper'

RSpec.describe "VettingController", type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alex', last_name: 'Smith') }
  let(:support_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Alex', last_name: 'Smith',
                          email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'pending')
  end
  let(:plain_user) { User.create!(email: 'plain@test.com', password: 'password123', first_name: 'Jan', last_name: 'Doe') }

  let(:chat_params) { { message: 'My police check number is ABC123456', history: [] } }

  let(:text_reply) do
    { 'content' => [{ 'type' => 'text', 'text' => 'Thank you! Now please provide your WWCC number.' }] }
  end

  let(:complete_reply) do
    { 'content' => [{ 'type' => 'text', 'text' => "Great, all done! [VETTING_COMPLETE]" }] }
  end

  let(:extracted_data) do
    { 'content' => [{ 'type' => 'text', 'text' => '{"police_check_number":"ABC123456","police_check_expiry":"2028-03-01","wwcc_number":"WWC7654321","wwcc_expiry":"2027-06-01","recommendation":"approved","notes":"All checks passed"}' }] }
  end

  describe "POST /api/vetting/chat" do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post '/api/vetting/chat', params: chat_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as a user without a support worker profile' do
      before { plain_user; post api_login_path, params: { email: plain_user.email, password: 'password123' } }

      it 'returns forbidden' do
        post '/api/vetting/chat', params: chat_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a support worker' do
      before { support_worker; post api_login_path, params: { email: sw_user.email, password: 'password123' } }

      it 'returns the assistant reply' do
        anthropic_client = double
        allow(Anthropic::Client).to receive(:new).and_return(anthropic_client)
        allow(anthropic_client).to receive(:messages).and_return(text_reply)
        post '/api/vetting/chat', params: chat_params
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['reply']).to eq('Thank you! Now please provide your WWCC number.')
        expect(body['complete']).to be_falsey
      end

      it 'marks complete and updates the worker when VETTING_COMPLETE is present' do
        anthropic_client = double
        allow(Anthropic::Client).to receive(:new).and_return(anthropic_client)
        allow(anthropic_client).to receive(:messages).and_return(complete_reply, extracted_data)
        post '/api/vetting/chat', params: {
          message: 'My WWCC is WWC7654321 and it expires June 2027',
          history: [{ role: 'user', content: 'ABC123456' }, { role: 'assistant', content: 'Thank you! When does it expire?' }, { role: 'user', content: 'March 2028' }, { role: 'assistant', content: 'Got it. Now your WWCC number?' }]
        }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['complete']).to be true
        expect(body['recommendation']).to eq('approved')
        expect(body['reply']).not_to include('[VETTING_COMPLETE]')
        support_worker.reload
        expect(support_worker.police_check_number).to eq('ABC123456')
        expect(support_worker.police_check_expiry).to eq(Date.new(2028, 3, 1))
        expect(support_worker.wwcc_number).to eq('WWC7654321')
        expect(support_worker.wwcc_expiry).to eq(Date.new(2027, 6, 1))
        expect(support_worker.agent_recommendation).to eq('approved')
      end

      it 'strips [VETTING_COMPLETE] from the reply text' do
        anthropic_client = double
        allow(Anthropic::Client).to receive(:new).and_return(anthropic_client)
        allow(anthropic_client).to receive(:messages).and_return(complete_reply, extracted_data)
        post '/api/vetting/chat', params: { message: 'WWC7654321 expires June 2027', history: [] }
        body = JSON.parse(response.body)
        expect(body['reply']).not_to include('[VETTING_COMPLETE]')
      end
    end
  end
end
