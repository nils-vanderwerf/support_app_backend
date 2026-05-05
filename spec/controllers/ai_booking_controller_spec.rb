require 'rails_helper'

RSpec.describe "AiBookingController", type: :request do
  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown',
                          email: 'sw@test.com', phone: '0400000000', age: 30, location: 'Sydney')
  end

  let(:messages_params) { { messages: [{ role: 'user', content: 'I need help with bathing' }] } }

  let(:text_response) do
    { 'content' => [{ 'type' => 'text', 'text' => 'I found some workers for you.' }], 'stop_reason' => 'end_turn' }
  end

  let(:tool_use_response) do
    {
      'content' => [{ 'type' => 'tool_use', 'id' => 'toolu_123', 'name' => 'get_support_workers', 'input' => {} }],
      'stop_reason' => 'tool_use'
    }
  end

  let(:final_text_response) do
    { 'content' => [{ 'type' => 'text', 'text' => 'Here are your options.' }], 'stop_reason' => 'end_turn' }
  end

  describe "POST /api/ai_booking/chat" do
    context 'when no user is logged in' do
      it 'returns unauthorized' do
        post '/api/ai_booking/chat', params: messages_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when a support worker (not a client) is logged in' do
      before do
        support_worker
        post api_login_path, params: { email: sw_user.email, password: 'password123' }
      end

      it 'returns forbidden' do
        post '/api/ai_booking/chat', params: messages_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when a client is logged in' do
      before do
        client
        post api_login_path, params: { email: client_user.email, password: 'password123' }
      end

      it 'returns the text reply from Claude' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(text_response)
        post '/api/ai_booking/chat', params: messages_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('I found some workers for you.')
      end

      it 'executes tool calls and returns the final text reply' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages)
          .and_return(tool_use_response, final_text_response)
        post '/api/ai_booking/chat', params: messages_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Here are your options.')
      end

      it 'creates an appointment when Claude calls create_appointment' do
        create_tool_response = {
          'content' => [{
            'type' => 'tool_use',
            'id' => 'toolu_456',
            'name' => 'create_appointment',
            'input' => {
              'support_worker_id' => support_worker.id,
              'date' => '2026-06-01T09:00:00',
              'duration' => 60,
              'location' => 'Sydney'
            }
          }],
          'stop_reason' => 'tool_use'
        }
        allow_any_instance_of(Anthropic::Client).to receive(:messages)
          .and_return(create_tool_response, final_text_response)
        expect {
          post '/api/ai_booking/chat', params: messages_params
        }.to change(Appointment, :count).by(1)
      end
    end
  end
end
