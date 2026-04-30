require 'rails_helper'

RSpec.describe "AppointmentsController", type: :request do
    let(:client_user) { User.create!(email: 'client@test.com', first_name: 'Jane', last_name: 'Doe', password: 'password123') }
    let(:client) { Client.create!(user_id: client_user.id, first_name: client_user.first_name, last_name: client_user.last_name) }
    let(:support_worker_user) { User.create!(email: 'test2@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown', role: 'support_worker') }
    let(:support_worker) { SupportWorker.create!(email: support_worker_user.email, phone: '6773 2092', age: 35, location: 'Sydney', user_id: support_worker_user.id, first_name: support_worker_user.first_name, last_name: support_worker_user.last_name) }
    let(:active_client_appointments) { 
      3.times.map {
        Appointment.create(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id )
      }
    }
    let(:active_support_worker_appointments) { 
      3.times.map {
        Appointment.create(deleted_at: nil, client_id: client.id, support_worker_id: support_worker.id )
      }
    }
    let(:soft_deleted_client_appointments) { 
        Appointment.create(deleted_at: Time.current, client_id: client.id, support_worker_id: support_worker.id )
    }
    let(:soft_deleted_support_worker_appointments) { 
        Appointment.create(deleted_at: Time.current, client_id: client.id, support_worker_id: support_worker.id )
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
      it 'returns the clients appointments' do
        get api_appointments_path
        expect(JSON.parse(response.body).count).to eq(3)
      end
    end
end
    