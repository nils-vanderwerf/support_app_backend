require 'rails_helper'

RSpec.describe "AppointmentsController", type: :request do
    let(:client_user) { User.create!(email: 'client@test.com', first_name: 'Jane', last_name: 'Doe', password: 'password123') }
    let(:client) { Client.create!(user_id: client_user.id, first_name: client_user.first_name, last_name: client_user.last_name) }
    let(:support_worker_user) { User.create!(email: 'test2@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown', role: 'support_worker') }
    let(:support_worker) { SupportWorker.create!(email: support_worker_user.email, phone: '6773 2092', location: 'Sydney', user_id: support_worker_user.id, first_name: support_worker_user.first_name, last_name: support_worker_user.last_name, status: 'approved') }
    let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending') }
    let(:pending_worker) { SupportWorker.create!(email: 'pending@test.com', phone: '0411111111', location: 'Melbourne', user_id: pending_sw_user.id, first_name: 'Pat', last_name: 'Pending', status: 'pending') }
    let(:appointment_params) { { appointment: { date: "2026-05-01", duration: 30, location: "location", notes: "some notes", client_id: client.id, support_worker_id: support_worker.id } } }
    let(:invalid_appointment_params) { { appointment: { duration: 30, location: "location", notes: "some notes", client_id: client.id, support_worker_id: support_worker.id, date: nil } } }
    let(:invalid_user) { User.create!(email: 'invalid@test.com', first_name: 'Invalid', last_name: 'User', password: 'password123') }
    let(:appointment) { Appointment.create(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id, date: '2026-04-30' ) }
    
    let(:active_client_appointments) {
      ['2026-04-28 09:00', '2026-04-29 09:00', '2026-04-30 09:00'].map do |date|
        Appointment.create!(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id, date: date)
      end
    }
    let(:active_support_worker_appointments) {
      ['2026-04-28 09:00', '2026-04-29 09:00', '2026-04-30 09:00'].map do |date|
        Appointment.create!(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id, date: date)
      end
    }
    let(:soft_deleted_client_appointments) { 
        Appointment.create(deleted_at: Time.current, client_id: client.id, support_worker_id: support_worker.id, date: '2026-04-30' )
    }
    let(:soft_deleted_support_worker_appointments) { 
        Appointment.create(deleted_at: Time.current, client_id: client.id, support_worker_id: support_worker.id, date: '2026-04-30' )
    }

    context 'for a logged in client user' do
      before do
          active_client_appointments
          soft_deleted_client_appointments
          post api_login_path, params: { email: client_user.email, password: 'password123' }
      end
      it 'returns the clients appointments' do
        get api_appointments_path
        expect(JSON.parse(response.body).count).to eq(3)
      end
    end
     context 'for a logged in support worker user' do
      before do
          active_support_worker_appointments
          soft_deleted_support_worker_appointments
          post api_login_path, params: { email: support_worker_user.email, password: 'password123' }
      end
      it 'returns the support workers appointments' do
        get api_appointments_path
        expect(JSON.parse(response.body).count).to eq(3)
      end
    end
    describe "POST /api/appointments" do
      context 'the client is logged in with valid params' do
        before do
          post api_login_path, params: { email: client_user.email, password: 'password123' }
        end
        it 'successfully creates an appointment' do
          post api_appointments_path, params: appointment_params
          expect(response).to have_http_status(:ok)
          expect(Appointment.count).to eq(1)
        end
      end
      context 'the support worker is logged in with valid params' do
        before do
          post api_login_path, params: { email: support_worker_user.email, password: 'password123' }
        end
        it 'successfully creates an appointment' do
          post api_appointments_path, params: appointment_params
          expect(response).to have_http_status(:ok)
          expect(Appointment.count).to eq(1)
        end
      end
      context "a user is not logged in and tries to create an appointment" do
        it 'returns unauthorized' do
          post api_appointments_path, params: appointment_params
          expect(response).to have_http_status(:unauthorized)
          expect(Appointment.count).to eq(0)
        end
      end
      context "a user does not have an associated client or support worker and tries to create an appointment" do
        before do
          post api_login_path, params: { email: invalid_user.email, password: 'password123' }
        end
        it 'returns unauthorized' do
          post api_appointments_path, params: appointment_params
          expect(response).to have_http_status(:forbidden)
          expect(Appointment.count).to eq(0)
        end
      end
    end
    describe "PATCH /api/appointment" do
      before do
        post api_login_path, params: { email: client_user.email, password: 'password123' }
        appointment
      end
       context 'when an appointment is updated with valid params' do
        it 'updates the appointment' do  
         patch api_appointment_path(appointment), params: appointment_params
         expect(appointment.reload.date).to eq('2026-05-01')
        end
      end
       context 'when an API call is made to an appointment invalid params' do
        it 'updates the appointment' do  
         patch api_appointment_path(appointment), params: invalid_appointment_params
         expect(response).to have_http_status(:unprocessable_entity)
         expect(appointment.reload.date).to eq('2026-04-30')
        end
      end
    end
    describe "DESTROY /api/appointment" do
      before do
        post api_login_path, params: { email: client_user.email, password: 'password123' }
      end
      context 'when an appointment is deleted' do
        it 'soft deletes it, leaπving a datetime value on the deleted_at column on the record' do
          delete api_appointment_path(appointment)
          expect(appointment.reload.deleted_at).not_to be nil
        end
      end
    end

    describe "PATCH /api/appointments/:id/approve" do
      let(:pending_appointment) { Appointment.create!(client_id: client.id, support_worker_id: support_worker.id, date: '2026-06-01 10:00', status: 'pending') }

      context 'when the client approves' do
        before { post api_login_path, params: { email: client_user.email, password: 'password123' } }

        it 'sets status to approved' do
          patch approve_api_appointment_path(pending_appointment), params: { timezone: 'Australia/Sydney' }
          expect(response).to have_http_status(:ok)
          expect(pending_appointment.reload.status).to eq('approved')
        end
      end

      context 'when the support worker approves' do
        before { post api_login_path, params: { email: support_worker_user.email, password: 'password123' } }

        it 'sets status to approved' do
          patch approve_api_appointment_path(pending_appointment), params: { timezone: 'Australia/Sydney' }
          expect(response).to have_http_status(:ok)
          expect(pending_appointment.reload.status).to eq('approved')
        end
      end
    end

    describe "PATCH /api/appointments/:id/decline" do
      let(:pending_appointment) { Appointment.create!(client_id: client.id, support_worker_id: support_worker.id, date: '2026-06-01 10:00', status: 'pending') }

      before { post api_login_path, params: { email: client_user.email, password: 'password123' } }

      it 'sets status to declined' do
        patch decline_api_appointment_path(pending_appointment), params: { timezone: 'Australia/Sydney' }
        expect(response).to have_http_status(:ok)
        expect(pending_appointment.reload.status).to eq('declined')
      end
    end

    describe "PATCH /api/appointments/bulk_approve" do
      let!(:pending1) { Appointment.create!(client_id: client.id, support_worker_id: support_worker.id, date: '2026-06-01 10:00', status: 'pending') }
      let!(:pending2) { Appointment.create!(client_id: client.id, support_worker_id: support_worker.id, date: '2026-06-08 10:00', status: 'pending') }

      before { post api_login_path, params: { email: client_user.email, password: 'password123' } }

      it 'approves all specified appointments in one request' do
        patch bulk_approve_api_appointments_path,
              params: { appointment_ids: [pending1.id, pending2.id], timezone: 'Australia/Sydney' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['approved_count']).to eq(2)
        expect(pending1.reload.status).to eq('approved')
        expect(pending2.reload.status).to eq('approved')
      end

      it 'ignores ids that are already approved' do
        already_approved = Appointment.create!(client_id: client.id, support_worker_id: support_worker.id, date: '2026-06-15 10:00', status: 'approved')
        patch bulk_approve_api_appointments_path,
              params: { appointment_ids: [pending1.id, already_approved.id], timezone: 'Australia/Sydney' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
        expect(JSON.parse(response.body)['approved_count']).to eq(1)
      end
    end

    describe "authorization — third-party cannot mutate appointments they don't own" do
      let(:other_user) { User.create!(email: 'other@test.com', first_name: 'Other', last_name: 'User', password: 'password123') }
      let(:other_client) { Client.create!(user_id: other_user.id, first_name: 'Other', last_name: 'User') }
      let(:owned_appointment) { Appointment.create!(client_id: client.id, support_worker_id: support_worker.id, date: '2026-06-01 10:00', status: 'pending') }

      before do
        other_client
        post api_login_path, params: { email: other_user.email, password: 'password123' }
      end

      it 'returns forbidden when a third party tries to approve' do
        patch approve_api_appointment_path(owned_appointment), params: { timezone: 'Australia/Sydney' }
        expect(response).to have_http_status(:forbidden)
        expect(owned_appointment.reload.status).to eq('pending')
      end

      it 'returns forbidden when a third party tries to decline' do
        patch decline_api_appointment_path(owned_appointment), params: { timezone: 'Australia/Sydney' }
        expect(response).to have_http_status(:forbidden)
        expect(owned_appointment.reload.status).to eq('pending')
      end

      it 'returns forbidden when a third party tries to update' do
        patch api_appointment_path(owned_appointment), params: { appointment: { location: 'Hacked location' } }
        expect(response).to have_http_status(:forbidden)
        expect(owned_appointment.reload.location).not_to eq('Hacked location')
      end

      it 'returns forbidden when a third party tries to delete' do
        delete api_appointment_path(owned_appointment)
        expect(response).to have_http_status(:forbidden)
        expect(owned_appointment.reload.deleted_at).to be_nil
      end

      it 'silently ignores appointments the user does not own in bulk_approve' do
        patch bulk_approve_api_appointments_path,
              params: { appointment_ids: [owned_appointment.id] }.to_json,
              headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['approved_count']).to eq(0)
        expect(owned_appointment.reload.status).to eq('pending')
      end

      it 'returns unauthorized when not logged in' do
        delete api_logout_path
        patch approve_api_appointment_path(owned_appointment), params: { timezone: 'Australia/Sydney' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "pending support worker restrictions" do
      before { pending_worker; post api_login_path, params: { email: pending_sw_user.email, password: 'password123' } }

      it 'returns an empty list for GET /api/appointments' do
        get api_appointments_path
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_empty
      end

      it 'returns forbidden for POST /api/appointments' do
        post api_appointments_path, params: appointment_params
        expect(response).to have_http_status(:forbidden)
        expect(Appointment.count).to eq(0)
      end
    end
end
    