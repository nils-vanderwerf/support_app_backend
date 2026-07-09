require 'rails_helper'

RSpec.describe "AiBookingController", type: :request do
  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown',
                          email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved')
  end
  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending') }
  let(:pending_worker) do
    SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending',
                          email: 'pending@test.com', phone: '0411111111', location: 'Melbourne', status: 'pending')
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

    context 'when a pending support worker is logged in' do
      before do
        pending_worker
        post api_login_path, params: { email: pending_sw_user.email, password: 'password123' }
      end

      it 'returns forbidden' do
        post '/api/ai_booking/chat', params: messages_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when an approved support worker is logged in' do
      before do
        support_worker
        post api_login_path, params: { email: sw_user.email, password: 'password123' }
      end

      it 'returns the text reply from Claude' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(text_response)
        post '/api/ai_booking/chat', params: messages_params
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('I found some workers for you.')
      end

      it 'includes an empty tool_calls array in the response' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_return(text_response)
        post '/api/ai_booking/chat', params: messages_params
        expect(JSON.parse(response.body)['tool_calls']).to eq([])
      end

      it 'instructs the model to check support_needs alongside health_conditions, not instead of it' do
        captured_system_prompt = nil
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
          captured_system_prompt = parameters[:system]
          text_response
        end

        post '/api/ai_booking/chat', params: messages_params

        expect(captured_system_prompt).to include('support_needs')
        expect(captured_system_prompt).to include('health_conditions')
      end

      it 'includes bio and support_needs in get_clients results, but not medication or allergies, regardless of any appointment' do
        client.update!(bio: 'Loves gardening', support_needs: 'Regular check-ins, prefers mornings', medication: 'Metformin', allergies: 'Peanuts')
        get_clients_response = {
          'content' => [{ 'type' => 'tool_use', 'id' => 'toolu_1', 'name' => 'get_clients', 'input' => {} }],
          'stop_reason' => 'tool_use'
        }
        second_call_messages = nil
        call_count = 0
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
          call_count += 1
          second_call_messages = parameters[:messages] if call_count == 2
          call_count == 1 ? get_clients_response : final_text_response
        end

        post '/api/ai_booking/chat', params: messages_params

        tool_result = second_call_messages.last[:content].first
        results = JSON.parse(tool_result[:content])
        entry = results.find { |r| r['id'] == client.id }
        expect(entry).to include('bio' => 'Loves gardening', 'support_needs' => 'Regular check-ins, prefers mornings')
        expect(entry.keys).not_to include('medication', 'allergies')
      end

      it 'excludes clients the worker already has an approved appointment with when new_clients_only is set' do
        existing_client_user = User.create!(email: 'existing@test.com', password: 'password123', first_name: 'Amy', last_name: 'Existing')
        existing_client = Client.create!(user: existing_client_user, first_name: 'Amy', last_name: 'Existing')
        Appointment.create!(client: existing_client, support_worker: support_worker, date: 1.week.ago, status: 'approved')

        new_client_user = User.create!(email: 'newclient@test.com', password: 'password123', first_name: 'Nina', last_name: 'New')
        new_client = Client.create!(user: new_client_user, first_name: 'Nina', last_name: 'New')

        get_clients_response = {
          'content' => [{ 'type' => 'tool_use', 'id' => 'toolu_1', 'name' => 'get_clients', 'input' => { 'new_clients_only' => true } }],
          'stop_reason' => 'tool_use'
        }
        second_call_messages = nil
        call_count = 0
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
          call_count += 1
          second_call_messages = parameters[:messages] if call_count == 2
          call_count == 1 ? get_clients_response : final_text_response
        end

        post '/api/ai_booking/chat', params: messages_params

        tool_result = second_call_messages.last[:content].first
        ids = JSON.parse(tool_result[:content]).map { |r| r['id'] }
        expect(ids).to include(new_client.id)
        expect(ids).not_to include(existing_client.id)
      end

      it 'includes existing clients when new_clients_only is not set' do
        existing_client_user = User.create!(email: 'existing2@test.com', password: 'password123', first_name: 'Amy', last_name: 'Existing')
        existing_client = Client.create!(user: existing_client_user, first_name: 'Amy', last_name: 'Existing')
        Appointment.create!(client: existing_client, support_worker: support_worker, date: 1.week.ago, status: 'approved')

        get_clients_response = {
          'content' => [{ 'type' => 'tool_use', 'id' => 'toolu_1', 'name' => 'get_clients', 'input' => {} }],
          'stop_reason' => 'tool_use'
        }
        second_call_messages = nil
        call_count = 0
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
          call_count += 1
          second_call_messages = parameters[:messages] if call_count == 2
          call_count == 1 ? get_clients_response : final_text_response
        end

        post '/api/ai_booking/chat', params: messages_params

        tool_result = second_call_messages.last[:content].first
        ids = JSON.parse(tool_result[:content]).map { |r| r['id'] }
        expect(ids).to include(existing_client.id)
      end

      it 'instructs the model to use new_clients_only when the worker asks for someone they have not worked with' do
        captured_system_prompt = nil
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
          captured_system_prompt = parameters[:system]
          text_response
        end

        post '/api/ai_booking/chat', params: messages_params

        expect(captured_system_prompt).to include('new_clients_only')
        expect(captured_system_prompt.downcase).to include('not worked with')
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

      it 'includes tool call details in the response when tools are used' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages)
          .and_return(tool_use_response, final_text_response)
        post '/api/ai_booking/chat', params: messages_params
        body = JSON.parse(response.body)
        expect(body['tool_calls']).to be_an(Array)
        expect(body['tool_calls'].first['name']).to eq('get_support_workers')
      end

      it 'stops after a bounded number of tool-calling iterations instead of looping forever' do
        call_count = 0
        # A finite guard rail so a real regression fails fast with a clear error
        # instead of hanging the test suite on a genuinely infinite loop.
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do
          call_count += 1
          raise "runaway loop: called Claude #{call_count} times with no cap enforced" if call_count > 20
          tool_use_response
        end

        post '/api/ai_booking/chat', params: messages_params

        expect(response).to have_http_status(:ok)
        expect(call_count).to be <= 6
        expect(JSON.parse(response.body)['message']).to be_present
      end

      it 'does not open a conversation when Claude supplies a person_id that does not exist' do
        bogus_id_response = {
          'content' => [{
            'type' => 'tool_use',
            'id' => 'toolu_999',
            'name' => 'open_conversation',
            'input' => { 'person_id' => 999_999 }
          }],
          'stop_reason' => 'tool_use'
        }
        allow_any_instance_of(Anthropic::Client).to receive(:messages)
          .and_return(bogus_id_response, final_text_response)

        expect {
          post '/api/ai_booking/chat', params: messages_params
        }.not_to change(Conversation, :count)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['conversation_id']).to be_nil
      end

      it 'tells the model the tool call failed, rather than falsely reporting success' do
        bogus_id_response = {
          'content' => [{
            'type' => 'tool_use',
            'id' => 'toolu_999',
            'name' => 'open_conversation',
            'input' => { 'person_id' => 999_999 }
          }],
          'stop_reason' => 'tool_use'
        }
        second_call_messages = nil
        call_count = 0
        allow_any_instance_of(Anthropic::Client).to receive(:messages) do |_, parameters:|
          call_count += 1
          second_call_messages = parameters[:messages] if call_count == 2
          call_count == 1 ? bogus_id_response : final_text_response
        end

        post '/api/ai_booking/chat', params: messages_params

        tool_result = second_call_messages.last[:content].first
        result_payload = JSON.parse(tool_result[:content])
        expect(result_payload['success']).to eq(false)
      end

      it 'returns a clear ai_unavailable error instead of an unhandled 500 when Claude is unreachable' do
        allow_any_instance_of(Anthropic::Client).to receive(:messages).and_raise(StandardError.new('connection failed'))

        post '/api/ai_booking/chat', params: messages_params

        expect(response).to have_http_status(:service_unavailable)
        expect(JSON.parse(response.body)['error']).to eq('ai_unavailable')
      end

      it 'opens a conversation when Claude calls open_conversation' do
        open_conv_response = {
          'content' => [{
            'type' => 'tool_use',
            'id' => 'toolu_789',
            'name' => 'open_conversation',
            'input' => { 'person_id' => support_worker.id }
          }],
          'stop_reason' => 'tool_use'
        }
        allow_any_instance_of(Anthropic::Client).to receive(:messages)
          .and_return(open_conv_response, final_text_response)
        expect {
          post '/api/ai_booking/chat', params: messages_params
        }.to change(Conversation, :count).by(1)
        expect(JSON.parse(response.body)['conversation_id']).to be_present
      end
    end
  end
end
