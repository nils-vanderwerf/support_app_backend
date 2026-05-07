require 'rails_helper'

RSpec.describe "AdminController", type: :request do
  let(:admin_user) { User.create!(email: 'admin@test.com', password: 'password123', first_name: 'Admin', last_name: 'User', is_admin: true) }
  let(:plain_user)  { User.create!(email: 'plain@test.com', password: 'password123', first_name: 'Jan', last_name: 'Doe') }

  let(:other_admin_user) { User.create!(email: 'admin2@test.com', password: 'password123', first_name: 'Other', last_name: 'Admin', is_admin: true) }

  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:approved_worker) do
    SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown',
                          email: 'sw@test.com', phone: '0400000000', age: 30, location: 'Sydney',
                          status: 'approved', approved_by_id: admin_user.id)
  end

  let(:other_sw_user) { User.create!(email: 'other_sw@test.com', password: 'password123', first_name: 'Sara', last_name: 'Green') }
  let(:other_approved_worker) do
    SupportWorker.create!(user: other_sw_user, first_name: 'Sara', last_name: 'Green',
                          email: 'other_sw@test.com', phone: '0422222222', age: 28, location: 'Brisbane',
                          status: 'approved', approved_by_id: other_admin_user.id)
  end

  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending') }
  let(:pending_worker) do
    SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending',
                          email: 'pending@test.com', phone: '0411111111', age: 25, location: 'Melbourne', status: 'pending')
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
        approved_worker; other_approved_worker; pending_worker; client
        login_as(admin_user)
      end

      it 'counts only workers this admin approved' do
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

    it 'sets the worker status to approved and records the approving admin' do
      patch "/api/admin/applications/#{pending_worker.id}/approve"
      expect(response).to have_http_status(:ok)
      expect(pending_worker.reload.status).to eq('approved')
      expect(pending_worker.reload.approved_by_id).to eq(admin_user.id)
    end
  end

  describe "PATCH /api/admin/applications/:id/reject" do
    before { pending_worker; login_as(admin_user) }

    it 'sets the worker status to rejected' do
      patch "/api/admin/applications/#{pending_worker.id}/reject"
      expect(response).to have_http_status(:ok)
      expect(pending_worker.reload.status).to eq('rejected')
    end
  end
end
