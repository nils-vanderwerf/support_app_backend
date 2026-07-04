require 'rails_helper'

RSpec.describe "VettingController", type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alex', last_name: 'Smith') }
  let(:support_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Alex', last_name: 'Smith',
                          email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'pending')
  end
  let(:plain_user) { User.create!(email: 'plain@test.com', password: 'password123', first_name: 'Jan', last_name: 'Doe') }

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

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

  describe "GET /api/vetting/status" do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get '/api/vetting/status'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as a user without a support worker profile' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/vetting/status'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when support worker has not been rejected' do
      before { support_worker; login_as(sw_user) }

      it 'returns waiting_period false' do
        get '/api/vetting/status'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['waiting_period']).to be false
      end
    end

    context 'when support worker was rejected within the last 3 days' do
      before do
        support_worker.update!(rejected_at: 1.day.ago)
        login_as(sw_user)
      end

      it 'returns waiting_period true with reapply_at' do
        get '/api/vetting/status'
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['waiting_period']).to be true
        expect(body['reapply_at']).to be_present
      end
    end

    context 'when support worker was rejected more than 3 days ago' do
      before do
        support_worker.update!(rejected_at: 4.days.ago)
        login_as(sw_user)
      end

      it 'returns waiting_period false' do
        get '/api/vetting/status'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['waiting_period']).to be false
      end
    end
  end

  describe "POST /api/vetting/submit" do
    let(:valid_params) do
      {
        state:               'nsw',
        police_check_number: 'ABC1234567',
        police_check_expiry: 2.years.from_now.to_date.to_s,
        wwcc_number:         'WWC1234567E',
        wwcc_expiry:         2.years.from_now.to_date.to_s,
      }
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post '/api/vetting/submit', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as a user without a support worker profile' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        post '/api/vetting/submit', params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a support worker' do
      before { support_worker; login_as(sw_user) }

      it 'approves the worker and saves check details with valid params' do
        post '/api/vetting/submit', params: valid_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['status']).to eq('approved')
        support_worker.reload
        expect(support_worker.status).to eq('approved')
        expect(support_worker.state).to eq('nsw')
        expect(support_worker.police_check_number).to eq('ABC1234567')
        expect(support_worker.wwcc_number).to eq('WWC1234567E')
      end

      it 'returns errors for an invalid police check number' do
        post '/api/vetting/submit', params: valid_params.merge(police_check_number: 'SHORT')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['police_check_number']).to be_present
      end

      it 'returns errors for a WWCC number that does not match the state pattern' do
        post '/api/vetting/submit', params: valid_params.merge(wwcc_number: 'BADFORMAT')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['wwcc_number']).to be_present
      end

      it 'returns errors for an expired police check' do
        post '/api/vetting/submit', params: valid_params.merge(police_check_expiry: 1.year.ago.to_date.to_s)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['police_check_expiry']).to be_present
      end

      it 'returns errors for an invalid state' do
        post '/api/vetting/submit', params: valid_params.merge(state: 'invalid')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']['state']).to be_present
      end

      it 'returns errors for a malformed date' do
        post '/api/vetting/submit', params: valid_params.merge(police_check_expiry: 'not-a-date')
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/vetting/chat" do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post '/api/vetting/chat', params: chat_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as a user without a support worker profile' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        post '/api/vetting/chat', params: chat_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when support worker was rejected within the last 3 days' do
      before do
        support_worker.update!(rejected_at: 2.days.ago)
        login_as(sw_user)
      end

      it 'returns forbidden with waiting_period error' do
        post '/api/vetting/chat', params: chat_params
        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('waiting_period')
        expect(body['reapply_at']).to be_present
      end
    end

    context 'when logged in as a support worker' do
      before { support_worker; login_as(sw_user) }

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

      it 'enqueues the vetting email rather than sending inline on completion' do
        anthropic_client = double
        allow(Anthropic::Client).to receive(:new).and_return(anthropic_client)
        allow(anthropic_client).to receive(:messages).and_return(complete_reply, extracted_data)
        expect {
          post '/api/vetting/chat', params: { message: 'WWC7654321 expires June 2027', history: [] }
        }.to have_enqueued_mail(VettingMailer, :application_received)
      end
    end
  end
end
