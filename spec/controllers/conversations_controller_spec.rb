require 'rails_helper'

RSpec.describe 'ConversationsController', type: :request do
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

    # Support worker — specialization fit
    it 'instructs the SW to check specialization fit in the opening message' do
      persona = controller_instance.send(:build_persona, sw_near, 'support_worker', client, [], [])
      expect(persona).to include('Specialization fit')
    end

    it 'includes SW specializations and client needs in the SW persona' do
      persona = controller_instance.send(:build_persona, sw_near, 'support_worker', client, [], [])
      expect(persona).to include('Specializations')
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

    # Client — specialization fit
    it 'instructs the client to check specialization fit in the opening message' do
      persona = controller_instance.send(:build_persona, client, 'client', sw_near, [], [])
      expect(persona).to include('Specialization fit')
    end
  end
end
