require 'rails_helper'

RSpec.describe "AdminController", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:admin_user) { User.create!(email: 'admin@test.com', password: 'password123', first_name: 'Admin', last_name: 'User', role: :admin) }
  let(:plain_user)  { User.create!(email: 'plain@test.com', password: 'password123', first_name: 'Jan', last_name: 'Doe') }

  let(:other_admin_user) { User.create!(email: 'admin2@test.com', password: 'password123', first_name: 'Other', last_name: 'Admin', role: :admin) }

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

  let(:other_client_user) { User.create!(email: 'otherclient@test.com', password: 'password123', first_name: 'Sam', last_name: 'Jones') }
  let(:other_client) { Client.create!(user: other_client_user, first_name: 'Sam', last_name: 'Jones') }

  let(:appointment_with_admin_worker) do
    Appointment.create!(client: client, support_worker: approved_worker,
                        date: Time.current + 1.day, duration: 60, location: 'Sydney', status: 'approved')
  end
  let(:appointment_with_other_worker) do
    Appointment.create!(client: other_client, support_worker: other_approved_worker,
                        date: Time.current + 2.days, duration: 60, location: 'Brisbane', status: 'approved')
  end

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe "GET /api/admin/stats" do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/api/admin/stats'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not an admin' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/admin/stats'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before do
        # Anchor to a safe midweek moment before creating fixtures — the appointments
        # below are offset by +1/+2 days, which flakily rolled into next week whenever
        # the suite happened to run on a Saturday or Sunday.
        travel_to Time.current.beginning_of_week + 2.days
        approved_worker; other_approved_worker; pending_worker
        appointment_with_admin_worker; appointment_with_other_worker
        login_as(admin_user)
      end

      after { travel_back }

      it 'scopes all counts to this admin' do
        get '/api/admin/stats'
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['approved_workers']).to eq(1)
        expect(body['pending_workers']).to eq(1)
        expect(body['total_clients']).to eq(1)
        expect(body['appointments_this_week']).to eq(1)
      end
    end
  end

  describe "GET /api/admin/workers" do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/api/admin/workers'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not an admin' do
      before { plain_user; login_as(plain_user) }

      it 'returns forbidden' do
        get '/api/admin/workers'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { approved_worker; other_approved_worker; pending_worker; login_as(admin_user) }

      it 'returns only workers this admin approved' do
        get '/api/admin/workers'
        expect(response).to have_http_status(:ok)
        names = JSON.parse(response.body).map { |w| w['first_name'] }
        expect(names).to include('Bob')
        expect(names).not_to include('Sara')
        expect(names).not_to include('Pat')
      end
    end
  end

  describe "GET /api/admin/appointments" do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/api/admin/appointments'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as admin' do
      before do
        appointment_with_admin_worker; appointment_with_other_worker
        login_as(admin_user)
      end

      it 'returns only appointments for workers this admin approved' do
        get '/api/admin/appointments'
        expect(response).to have_http_status(:ok)
        ids = JSON.parse(response.body).map { |a| a['id'] }
        expect(ids).to include(appointment_with_admin_worker.id)
        expect(ids).not_to include(appointment_with_other_worker.id)
      end
    end
  end

  describe "GET /api/admin/applications" do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/api/admin/applications'
        expect(response).to have_http_status(:unauthorized)
      end
    end

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
    context 'when not logged in' do
      it 'returns unauthorized' do
        patch "/api/admin/applications/0/approve"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as admin' do
      before { pending_worker; login_as(admin_user) }

      it 'sets the worker status to approved and records the approving admin' do
        patch "/api/admin/applications/#{pending_worker.id}/approve"
        expect(response).to have_http_status(:ok)
        expect(pending_worker.reload.status).to eq('approved')
        expect(pending_worker.reload.approved_by_id).to eq(admin_user.id)
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
  end

  describe "PATCH /api/admin/applications/:id/reject" do
    context 'when not logged in' do
      it 'returns unauthorized' do
        patch "/api/admin/applications/0/reject"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as admin' do
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
  end

  describe "GET /api/admin/messages" do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/api/admin/messages'
        expect(response).to have_http_status(:unauthorized)
      end
    end

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
    context 'when not logged in' do
      it 'returns unauthorized' do
        post "/api/admin/messages/0/reply", params: { content: 'Hack' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as admin' do
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
end
