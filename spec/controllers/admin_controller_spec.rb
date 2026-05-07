require 'rails_helper'

RSpec.describe "AdminController", type: :request do
  let(:admin_user) { User.create!(email: 'admin@test.com', password: 'password123', first_name: 'Admin', last_name: 'User', is_admin: true) }
  let(:plain_user)  { User.create!(email: 'plain@test.com', password: 'password123', first_name: 'Jan', last_name: 'Doe') }

  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:approved_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown',
                          email: 'sw@test.com', phone: '0400000000', location: 'Sydney',
                          status: 'approved', approved_by_id: admin_user.id)
  end

  let(:other_sw_user) { User.create!(email: 'other_sw@test.com', password: 'password123', first_name: 'Sara', last_name: 'Green') }
  let(:other_approved_worker) do
    SupportWorker.create!(user: other_sw_user, first_name: 'Sara', last_name: 'Green',
                          email: 'other_sw@test.com', phone: '0422222222', location: 'Brisbane',
                          status: 'approved', approved_by_id: other_admin_user.id)
  end

  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending') }
  let(:pending_worker) do
    SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending',
                          email: 'pending@test.com', phone: '0411111111', location: 'Melbourne', status: 'pending')
  end

  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Smith') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Smith') }

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe "GET /api/admin/stats" do
    context 'when not an admin' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/admin/stats'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before do
        approved_worker; pending_worker; client
        login_as(admin_user)
      end

      it 'returns correct counts' do
        get '/api/admin/stats'
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['approved_workers']).to eq(1)
        expect(body['pending_workers']).to eq(1)
        expect(body['total_clients']).to eq(1)
        expect(body).to have_key('appointments_this_week')
      end
    end
  end

  describe "GET /api/admin/workers" do
    context 'when not an admin' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/admin/workers'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { approved_worker; pending_worker; login_as(admin_user) }

      it 'returns only approved workers' do
        get '/api/admin/workers'
        expect(response).to have_http_status(:ok)
        names = JSON.parse(response.body).map { |w| w['first_name'] }
        expect(names).to include('Bob')
        expect(names).not_to include('Pat')
      end
    end
  end

  describe "GET /api/admin/applications" do
    context 'when logged in as admin' do
      before { approved_worker; pending_worker; login_as(admin_user) }

      it 'returns only pending applications' do
        get '/api/admin/applications'
        expect(response).to have_http_status(:ok)
        names = JSON.parse(response.body).map { |w| w['first_name'] }
        expect(names).to include('Pat')
        expect(names).not_to include('Bob')
      end
    end
  end

  describe "PATCH /api/admin/applications/:id/approve" do
    before { pending_worker; login_as(admin_user) }

    it 'sets the worker status to approved' do
      patch "/api/admin/applications/#{pending_worker.id}/approve"
      expect(response).to have_http_status(:ok)
      expect(pending_worker.reload.status).to eq('approved')
    end

    it 'creates an admin message notification for the worker' do
      patch "/api/admin/applications/#{pending_worker.id}/approve"
      msg = pending_worker.admin_messages.last
      expect(msg).not_to be_nil
      expect(msg.sender).to eq('admin')
      expect(msg.content).to include('approved')
    end

    it 'includes the note in the admin message when provided' do
      patch "/api/admin/applications/#{pending_worker.id}/approve", params: { note: 'Great credentials!' }
      msg = pending_worker.admin_messages.last
      expect(msg.content).to include('Great credentials!')
    end

    it 'returns forbidden for non-admin' do
      plain_user
      post api_login_path, params: { email: plain_user.email, password: 'password123' }
      patch "/api/admin/applications/#{pending_worker.id}/approve"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/admin/applications/:id/reject" do
    before { pending_worker; login_as(admin_user) }

    it 'sets the worker status to rejected and records rejected_at' do
      patch "/api/admin/applications/#{pending_worker.id}/reject"
      expect(response).to have_http_status(:ok)
      expect(pending_worker.reload.status).to eq('rejected')
      expect(pending_worker.reload.rejected_at).to be_present
    end

    it 'creates a rejection admin message for the worker' do
      patch "/api/admin/applications/#{pending_worker.id}/reject"
      msg = pending_worker.admin_messages.last
      expect(msg).not_to be_nil
      expect(msg.sender).to eq('admin')
      expect(msg.content).to include('reapply')
    end

    it 'includes the note in the rejection message when provided' do
      patch "/api/admin/applications/#{pending_worker.id}/reject", params: { note: 'Please update your credentials.' }
      msg = pending_worker.admin_messages.last
      expect(msg.content).to include('Please update your credentials.')
    end
  end

  describe "GET /api/admin/messages" do
    context 'when not an admin' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/admin/messages'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before do
        approved_worker
        approved_worker.admin_messages.create!(sender: 'support_worker', content: 'Hello admin!')
        login_as(admin_user)
      end

      it 'returns threads with messages and unread counts' do
        get '/api/admin/messages'
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to be_an(Array)
        thread = body.first
        expect(thread['support_worker']['first_name']).to eq('Bob')
        expect(thread['messages'].first['content']).to eq('Hello admin!')
        expect(thread['unread_count']).to eq(1)
      end
    end
  end

  describe "POST /api/admin/messages/:support_worker_id/reply" do
    before { approved_worker; login_as(admin_user) }

    it 'creates an admin reply message' do
      post "/api/admin/messages/#{approved_worker.id}/reply", params: { content: 'Thanks for reaching out!' }
      expect(response).to have_http_status(:created)
      msg = approved_worker.admin_messages.last
      expect(msg.sender).to eq('admin')
      expect(msg.content).to eq('Thanks for reaching out!')
    end

    it 'marks unread support_worker messages as read' do
      unread = approved_worker.admin_messages.create!(sender: 'support_worker', content: 'Hi')
      post "/api/admin/messages/#{approved_worker.id}/reply", params: { content: 'Response' }
      expect(unread.reload.read_at).to be_present
    end

    it 'returns forbidden for non-admin' do
      plain_user
      post api_login_path, params: { email: plain_user.email, password: 'password123' }
      post "/api/admin/messages/#{approved_worker.id}/reply", params: { content: 'Hack' }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
