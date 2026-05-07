require 'rails_helper'

RSpec.describe "AdminMessagesController", type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alex', last_name: 'Smith') }
  let(:support_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Alex', last_name: 'Smith',
                          email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved')
  end

  let(:plain_user) { User.create!(email: 'plain@test.com', password: 'password123', first_name: 'Jan', last_name: 'Doe') }

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe "GET /api/admin_messages" do
    context 'when unauthenticated' do
      it 'returns forbidden' do
        get '/api/admin_messages'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a user without a support worker profile' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/admin_messages'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a support worker' do
      before do
        support_worker
        support_worker.admin_messages.create!(sender: 'admin', content: 'Welcome!', read_at: nil)
        support_worker.admin_messages.create!(sender: 'support_worker', content: 'Thanks!')
        login_as(sw_user)
      end

      it 'returns all messages in order' do
        get '/api/admin_messages'
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.length).to eq(2)
        expect(body.first['content']).to eq('Welcome!')
      end

      it 'marks unread admin messages as read' do
        unread = support_worker.admin_messages.where(sender: 'admin', read_at: nil).first
        get '/api/admin_messages'
        expect(unread.reload.read_at).to be_present
      end
    end
  end

  describe "POST /api/admin_messages" do
    context 'when unauthenticated' do
      it 'returns forbidden' do
        post '/api/admin_messages', params: { content: 'Hello' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a support worker' do
      before { support_worker; login_as(sw_user) }

      it 'creates a message from the support worker' do
        post '/api/admin_messages', params: { content: 'I have a question about my application.' }
        expect(response).to have_http_status(:created)
        msg = support_worker.admin_messages.last
        expect(msg.sender).to eq('support_worker')
        expect(msg.content).to eq('I have a question about my application.')
      end

      it 'returns the created message' do
        post '/api/admin_messages', params: { content: 'Question here' }
        body = JSON.parse(response.body)
        expect(body['sender']).to eq('support_worker')
        expect(body['content']).to eq('Question here')
      end
    end
  end
end
