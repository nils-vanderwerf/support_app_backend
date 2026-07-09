require 'rails_helper'

RSpec.describe 'AppointmentNotesController', type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown', email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved') }

  let(:client_user) { User.create!(email: 'c@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }

  let(:other_sw_user) { User.create!(email: 'other@test.com', password: 'password123', first_name: 'Carol', last_name: 'Clark') }
  let(:other_worker) { SupportWorker.create!(user: other_sw_user, first_name: 'Carol', last_name: 'Clark', email: 'other@test.com', phone: '0411111111', location: 'Sydney', status: 'approved') }

  let(:appointment) { Appointment.create!(client: client, support_worker: support_worker, date: 1.week.ago, status: 'approved') }

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'GET /api/appointments/:appointment_id/note' do
    context 'when logged in as the worker who wrote the note' do
      before do
        support_worker
        appointment
        AppointmentNote.create!(appointment: appointment, support_worker_id: support_worker.id, content: 'Session went well.')
        login_as(sw_user)
      end

      it 'returns the note' do
        get api_appointment_note_path(appointment_id: appointment.id)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['content']).to eq('Session went well.')
      end
    end

    context 'when no note exists for this worker' do
      before { support_worker; appointment; login_as(sw_user) }

      it 'returns not found' do
        get api_appointment_note_path(appointment_id: appointment.id)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when another worker wrote the note' do
      before do
        other_worker
        other_appointment = Appointment.create!(client: client, support_worker: other_worker, date: 2.weeks.ago, status: 'approved')
        AppointmentNote.create!(appointment: other_appointment, support_worker_id: other_worker.id, content: 'Other worker note.')
        support_worker
        login_as(sw_user)
      end

      it 'does not expose the other worker\'s note' do
        other_note = AppointmentNote.last
        get api_appointment_note_path(appointment_id: other_note.appointment_id)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns forbidden' do
        get api_appointment_note_path(appointment_id: 1)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/appointments/:appointment_id/note' do
    before { support_worker; appointment; login_as(sw_user) }

    it 'creates a note for the appointment' do
      post api_appointment_note_path(appointment_id: appointment.id), params: { content: 'Client was in good spirits.' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['content']).to eq('Client was in good spirits.')
    end

    it 'upserts — updating an existing note on a second POST' do
      AppointmentNote.create!(appointment: appointment, support_worker_id: support_worker.id, content: 'Original notes.')
      post api_appointment_note_path(appointment_id: appointment.id), params: { content: 'Updated notes.' }
      expect(response).to have_http_status(:ok)
      expect(AppointmentNote.count).to eq(1)
      expect(AppointmentNote.first.content).to eq('Updated notes.')
    end

    it 'returns not found when the appointment belongs to another worker' do
      other_worker
      other_appt = Appointment.create!(client: client, support_worker: other_worker, date: 2.weeks.ago, status: 'approved')
      post api_appointment_note_path(appointment_id: other_appt.id), params: { content: 'Should not be allowed.' }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns unprocessable entity when content is blank' do
      post api_appointment_note_path(appointment_id: appointment.id), params: { content: '' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/appointments/:appointment_id/note' do
    before do
      support_worker
      appointment
      AppointmentNote.create!(appointment: appointment, support_worker_id: support_worker.id, content: 'Original.')
      login_as(sw_user)
    end

    it 'updates the note content' do
      patch api_appointment_note_path(appointment_id: appointment.id), params: { content: 'Updated content.' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['content']).to eq('Updated content.')
    end

    it 'returns not found for a note belonging to another worker' do
      other_worker
      login_as(other_sw_user)
      patch api_appointment_note_path(appointment_id: appointment.id), params: { content: 'Should fail.' }
      expect(response).to have_http_status(:not_found)
    end
  end
end
