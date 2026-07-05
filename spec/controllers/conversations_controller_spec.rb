require 'rails_helper'

RSpec.describe 'ConversationsController', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:client_user) { User.create!(email: 'client@test.com', first_name: 'Jane', last_name: 'Doe', password: 'password123') }
  let(:client) { Client.create!(user_id: client_user.id, first_name: client_user.first_name, last_name: client_user.last_name) }
  let(:sw_user) { User.create!(email: 'worker@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(email: sw_user.email, phone: '0400000000', location: 'Sydney', user_id: sw_user.id, first_name: sw_user.first_name, last_name: sw_user.last_name, status: 'approved') }

  let(:conversation_with_message) do
    conv = Conversation.create!(client_id: client.id, support_worker_id: support_worker.id)
    conv.messages.create!(content: 'Hello', sender_type: 'client', sender_id: client.id)
    conv
  end

  let(:empty_conversation) do
    Conversation.create!(client_id: client.id, support_worker_id: support_worker.id)
  end

  describe 'GET /api/conversations' do
    context 'as a client' do
      before { post api_login_path, params: { email: client_user.email, password: 'password123' } }

      it 'returns only conversations that have at least one message' do
        conversation_with_message
        empty_conversation

        get api_conversations_path
        ids = JSON.parse(response.body).map { |c| c['id'] }
        expect(ids).to include(conversation_with_message.id)
        expect(ids).not_to include(empty_conversation.id)
      end

      it 'returns an empty array when all conversations are empty' do
        empty_conversation

        get api_conversations_path
        expect(JSON.parse(response.body)).to eq([])
      end

      it 'includes message content in the response' do
        conversation_with_message

        get api_conversations_path
        messages = JSON.parse(response.body).first['messages']
        expect(messages).not_to be_empty
        expect(messages.first['content']).to eq('Hello')
      end
    end

    context 'as a support worker' do
      before { post api_login_path, params: { email: sw_user.email, password: 'password123' } }

      it 'excludes conversations with no messages' do
        conversation_with_message
        empty_conversation

        get api_conversations_path
        ids = JSON.parse(response.body).map { |c| c['id'] }
        expect(ids).to include(conversation_with_message.id)
        expect(ids).not_to include(empty_conversation.id)
      end
    end

  end

  describe 'GET /api/conversations/:id/suggest_booking' do
    before { post api_login_path, params: { email: client_user.email, password: 'password123' } }

    it 'returns the existing pending appointment directly instead of asking the model to re-derive it' do
      client.update!(location: 'Surry Hills NSW, Australia')
      conv = Conversation.create!(client_id: client.id, support_worker_id: support_worker.id)
      conv.messages.create!(content: 'lots of confusing back and forth about a display bug', sender_type: 'client', sender_id: client.id)
      # 2026-07-07T23:00:00Z is 2026-07-08 09:00 in Sydney (AEST, UTC+10, no DST in July)
      conv.appointments.create!(
        client_id: client.id, support_worker_id: support_worker.id, conversation_id: conv.id,
        date: Time.utc(2026, 7, 7, 23, 0, 0), duration: 60, location: 'Surry Hills Community Centre',
        notes: 'Weekly session', status: 'pending'
      )

      expect(Anthropic::Client).not_to receive(:new)

      get suggest_booking_api_conversation_path(conv)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['date']).to eq('2026-07-08')
      expect(body['time']).to eq('09:00')
      expect(body['duration']).to eq(60)
      expect(body['location']).to eq('Surry Hills Community Centre')
    end

    it "returns a clear error instead of a silent blank result when the model call itself fails" do
      conversation_with_message
      fake_client = instance_double(Anthropic::Client)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)
      allow(fake_client).to receive(:messages).and_raise(Net::ReadTimeout.new('timed out'))

      get suggest_booking_api_conversation_path(conversation_with_message)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['error']).to be_present
    end

    it "returns a clear error instead of a silent blank result when the model response isn't valid JSON" do
      conversation_with_message
      fake_client = instance_double(Anthropic::Client)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)
      allow(fake_client).to receive(:messages).and_return(
        { 'content' => [{ 'type' => 'text', 'text' => 'not json' }] }
      )

      get suggest_booking_api_conversation_path(conversation_with_message)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['error']).to be_present
    end

    it 'includes messages from well before the most recent 12 in the transcript sent to the model' do
      conv = Conversation.create!(client_id: client.id, support_worker_id: support_worker.id)
      conv.messages.create!(content: 'We just agreed on next Wednesday the 8th at 10am', sender_type: 'support_worker', sender_id: support_worker.id)
      # Pad with enough follow-up chatter that the agreement above would fall outside a 12-message window
      15.times { |i| conv.messages.create!(content: "filler message #{i}", sender_type: i.even? ? 'client' : 'support_worker', sender_id: client.id) }

      captured_messages = nil
      fake_client = instance_double(Anthropic::Client)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)
      allow(fake_client).to receive(:messages) do |parameters:|
        captured_messages = parameters[:messages]
        { 'content' => [{ 'type' => 'text', 'text' => '{}' }] }
      end

      get suggest_booking_api_conversation_path(conv)

      expect(response).to have_http_status(:ok)
      expect(captured_messages.first[:content]).to include('next Wednesday the 8th at 10am')
    end

    it "resolves 'today' using the requesting client's own account location, not the server's default zone" do
      client.update!(location: 'Surry Hills NSW, Australia')
      conversation_with_message
      # 2026-06-01 23:00 UTC is already 2026-06-02 09:00 in Sydney (AEST, UTC+10, no DST in June)
      travel_to Time.utc(2026, 6, 1, 23, 0, 0) do
        captured_system_prompt = nil
        fake_client = instance_double(Anthropic::Client)
        allow(Anthropic::Client).to receive(:new).and_return(fake_client)
        allow(fake_client).to receive(:messages) do |parameters:|
          captured_system_prompt = parameters[:system]
          { 'content' => [{ 'type' => 'text', 'text' => '{}' }] }
        end

        get suggest_booking_api_conversation_path(conversation_with_message)

        expect(response).to have_http_status(:ok)
        expect(captured_system_prompt).to include('Today is 2026-06-02')
      end
    end

    it "uses a Perth-based user's own timezone instead of Sydney's" do
      client.update!(location: 'Perth WA, Australia')
      conversation_with_message
      # 2026-06-01 15:00 UTC is already 2026-06-02 in Sydney (+10) but still 2026-06-01 in Perth (+8, no DST)
      travel_to Time.utc(2026, 6, 1, 15, 0, 0) do
        captured_system_prompt = nil
        fake_client = instance_double(Anthropic::Client)
        allow(Anthropic::Client).to receive(:new).and_return(fake_client)
        allow(fake_client).to receive(:messages) do |parameters:|
          captured_system_prompt = parameters[:system]
          { 'content' => [{ 'type' => 'text', 'text' => '{}' }] }
        end

        get suggest_booking_api_conversation_path(conversation_with_message)

        expect(response).to have_http_status(:ok)
        expect(captured_system_prompt).to include('Today is 2026-06-01')
      end
    end

    it 'gives the model a lookup table instead of asking it to calculate weekday offsets' do
      conversation_with_message
      # 2026-07-05 is a Sunday, so 'next Wednesday' should map to 2026-07-08 — a case that
      # previously tripped up the model into computing 2026-07-09 (Thursday) by mistake.
      travel_to Time.utc(2026, 7, 5, 0, 0, 0) do
        captured_system_prompt = nil
        fake_client = instance_double(Anthropic::Client)
        allow(Anthropic::Client).to receive(:new).and_return(fake_client)
        allow(fake_client).to receive(:messages) do |parameters:|
          captured_system_prompt = parameters[:system]
          { 'content' => [{ 'type' => 'text', 'text' => '{}' }] }
        end

        get suggest_booking_api_conversation_path(conversation_with_message)

        expect(response).to have_http_status(:ok)
        expect(captured_system_prompt).to include('Wednesday=2026-07-08')
        expect(captured_system_prompt).to include('do NOT calculate the date yourself')
      end
    end

    it 'instructs the model to prefer the last confirmed date over one mentioned only in a complaint' do
      conversation_with_message

      captured_system_prompt = nil
      fake_client = instance_double(Anthropic::Client)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)
      allow(fake_client).to receive(:messages) do |parameters:|
        captured_system_prompt = parameters[:system]
        { 'content' => [{ 'type' => 'text', 'text' => '{}' }] }
      end

      get suggest_booking_api_conversation_path(conversation_with_message)

      expect(response).to have_http_status(:ok)
      expect(captured_system_prompt).to include('use the LAST date that was explicitly agreed or confirmed')
      expect(captured_system_prompt).to include('ignore dates that only appear inside a question, complaint, or error report')
    end
  end

  describe '#timezone_for_location' do
    let(:controller_instance) { Api::ConversationsController.new }

    it 'maps a Perth/WA location to Australia/Perth' do
      tz = controller_instance.send(:timezone_for_location, 'Perth WA, Australia')
      expect(tz.tzinfo.name).to eq('Australia/Perth')
    end

    it 'maps a Sydney/NSW location to Australia/Sydney' do
      tz = controller_instance.send(:timezone_for_location, 'Surry Hills NSW, Australia')
      expect(tz.tzinfo.name).to eq('Australia/Sydney')
    end

    it 'defaults to Australia/Sydney when location is blank' do
      tz = controller_instance.send(:timezone_for_location, nil)
      expect(tz.tzinfo.name).to eq('Australia/Sydney')
    end
  end

  describe '#build_persona — pending appointment timezone' do
    let(:controller_instance) { Api::ConversationsController.new }
    let(:sw)     { SupportWorker.new(first_name: 'Olivia', last_name: 'Williams', location: 'Surry Hills, Sydney') }
    let(:client_record) { Client.new(first_name: 'Elena', last_name: 'Martinez', location: 'Surry Hills, Sydney') }

    it "describes the pending appointment in the client's local timezone, not raw UTC" do
      # 2026-07-07T23:00:00Z is 2026-07-08 09:00 in Sydney (AEST, UTC+10, no DST in July)
      pending = Appointment.new(date: Time.utc(2026, 7, 7, 23, 0, 0), duration: 60, location: 'Home')

      persona = controller_instance.send(
        :build_persona, sw, 'support_worker', client_record, [pending], [], ActiveSupport::TimeZone['Australia/Sydney']
      )

      expect(persona).to include('Wednesday, Jul 8 at 9:00 AM')
      expect(persona).not_to include('Tuesday, Jul 7')
    end

    it "describes the same instant differently for a Perth-based person than a Sydney-based one" do
      # 2026-07-07T23:00:00Z is 9am in Sydney (+10) but 7am in Perth (+8, no DST)
      pending = Appointment.new(date: Time.utc(2026, 7, 7, 23, 0, 0), duration: 60, location: 'Home')
      perth_tz = controller_instance.send(:timezone_for_location, 'Perth WA, Australia')

      persona = controller_instance.send(
        :build_persona, sw, 'support_worker', client_record, [pending], [], perth_tz
      )

      expect(persona).to include('7:00 AM')
      expect(persona).not_to include('9:00 AM')
    end
  end

  describe '#build_persona — fit checks' do
    let(:controller_instance) { Api::ConversationsController.new }

    let(:sw_far)   { SupportWorker.new(first_name: 'James',  last_name: 'Smith',    location: 'Melbourne') }
    let(:sw_near)  { SupportWorker.new(first_name: 'Olivia', last_name: 'Williams', location: 'Surry Hills, Sydney') }
    let(:client)   { Client.new(first_name: 'Elena', last_name: 'Martinez',         location: 'Surry Hills, Sydney') }

    # Support worker — distance
    it 'instructs the SW to assess distance in the opening message' do
      persona = controller_instance.send(:build_persona, sw_far, 'support_worker', client, [], [])
      expect(persona).to include('OPENING MESSAGE')
      expect(persona).to include('100 km')
    end

    it 'requires the SW to decline in the first message when too far' do
      persona = controller_instance.send(:build_persona, sw_far, 'support_worker', client, [], [])
      expect(persona).to include('you MUST decline in your very first message')
    end

    it 'tells the SW to suggest the Suppova location filter when declining' do
      persona = controller_instance.send(:build_persona, sw_far, 'support_worker', client, [], [])
      expect(persona).to include('Suppova')
      expect(persona).to include('location filter')
    end

    it 'includes both locations in the SW persona' do
      persona = controller_instance.send(:build_persona, sw_far, 'support_worker', client, [], [])
      expect(persona).to include('Melbourne')
      expect(persona).to include('Surry Hills, Sydney')
    end

    # Support worker — specialisation fit
    it 'instructs the SW to check specialisation fit in the opening message' do
      persona = controller_instance.send(:build_persona, sw_near, 'support_worker', client, [], [])
      expect(persona).to include('Specialisation fit')
    end

    it 'includes SW specialisations and client needs in the SW persona' do
      persona = controller_instance.send(:build_persona, sw_near, 'support_worker', client, [], [])
      expect(persona).to include('Specialisations')
      expect(persona).to include('needs')
    end

    # Client — distance
    it 'instructs the client to assess distance in the opening message' do
      persona = controller_instance.send(:build_persona, client, 'client', sw_far, [], [])
      expect(persona).to include('OPENING MESSAGE')
      expect(persona).to include('100 km')
    end

    it 'allows the client to decline bluntly without being diplomatic' do
      persona = controller_instance.send(:build_persona, client, 'client', sw_far, [], [])
      expect(persona).to include("don't need to be polite")
    end

    # Client — specialisation fit
    it 'instructs the client to check specialisation fit in the opening message' do
      persona = controller_instance.send(:build_persona, client, 'client', sw_near, [], [])
      expect(persona).to include('Specialisation fit')
    end
  end
end
