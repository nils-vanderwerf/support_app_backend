require 'rails_helper'

RSpec.describe "AppointmentsController", type: :request do
    let(:client_user) { User.create!(email: 'client@test.com', first_name: 'Jane', last_name: 'Doe', password: 'password123') }
    let(:client) { Client.create!(user_id: client_user.id, first_name: client_user.first_name, last_name: client_user.last_name) }
    let(:support_worker_user) { User.create!(email: 'test2@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown', role: 'support_worker') }
    let(:support_worker) { SupportWorker.create!(email: support_worker_user.email, phone: '6773 2092', age: 35, location: 'Sydney', user_id: support_worker_user.id, first_name: support_worker_user.first_name, last_name: support_worker_user.last_name) }
    let(:appointment_params) { { appointment: { date: "2026-05-01", duration: 30, location: "location", notes: "some notes", client_id: client.id, support_worker_id: support_worker.id } } }
    let(:invalid_appointment_params) { { appointment: { duration: 30, location: "location", notes: "some notes", client_id: client.id, support_worker_id: support_worker.id, date: nil } } }
    let(:invalid_user) { User.create!(email: 'invalid@test.com', first_name: 'Invalid', last_name: 'User', password: 'password123') }
    let(:appointment) { Appointment.create(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id, date: '2026-04-30' ) }
    
    let(:active_client_appointments) { 
      3.times.map {
        Appointment.create(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id, date: '2026-04-30' )
      }
    }
    let(:active_support_worker_appointments) { 
      3.times.map {
        Appointment.create(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id, date: '2026-04-30' )
      }
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
end
    