require 'rails_helper'

RSpec.describe 'VisitReportsController', type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Alice', last_name: 'Smith', email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved') }
  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:appointment) { Appointment.create!(client: client, support_worker: support_worker, date: 1.day.ago) }

  let(:other_sw_user) { User.create!(email: 'other_sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Jones', role: 'support_worker') }
  let(:other_sw) { SupportWorker.create!(user: other_sw_user, first_name: 'Bob', last_name: 'Jones', email: 'other_sw@test.com', phone: '0411111111', location: 'Melbourne', status: 'pending') }

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'POST /api/visit_reports' do
    context 'as an approved support worker' do
      before do
        support_worker
        login_as(sw_user)
      end

      it 'creates a visit report and returns 200' do
        post api_visit_reports_path, params: {
          appointment_id: appointment.id,
          client_id: client.id,
          date: appointment.date,
          activities: 'Helped with cooking',
          observations: 'Client was engaged',
          follow_up_actions: 'Book next session'
        }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['activities']).to eq('Helped with cooking')
        expect(body['observations']).to eq('Client was engaged')
      end

      it 'upserts: updating an existing report for the same appointment' do
        VisitReport.create!(support_worker_id: support_worker.id, client_id: client.id, appointment_id: appointment.id,
                            date: appointment.date, activities: 'Old activity')
        post api_visit_reports_path, params: {
          appointment_id: appointment.id,
          client_id: client.id,
          date: appointment.date,
          activities: 'Updated activity'
        }
        expect(response).to have_http_status(:ok)
        expect(VisitReport.where(appointment_id: appointment.id).count).to eq(1)
        expect(VisitReport.find_by(appointment_id: appointment.id).activities).to eq('Updated activity')
      end
    end

    context 'as a pending (not approved) support worker' do
      before do
        other_sw
        login_as(other_sw_user)
      end

      it 'returns 403 forbidden' do
        post api_visit_reports_path, params: { appointment_id: appointment.id, client_id: client.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not logged in' do
      it 'returns 403 forbidden' do
        post api_visit_reports_path, params: { appointment_id: appointment.id }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/visit_reports' do
    before do
      support_worker
      VisitReport.create!(support_worker_id: support_worker.id, client_id: client.id, appointment_id: appointment.id,
                          date: appointment.date, activities: 'Cooking assistance')
      login_as(sw_user)
    end

    it 'returns the worker\'s visit reports' do
      get api_visit_reports_path
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first['activities']).to eq('Cooking assistance')
    end
  end

  describe 'PUT /api/visit_reports/:id' do
    let!(:report) do
      VisitReport.create!(support_worker_id: support_worker.id, client_id: client.id, appointment_id: appointment.id,
                          date: appointment.date, activities: 'Old activity', observations: 'Old obs', follow_up_actions: 'Old fup')
    end

    context 'as the owning approved support worker' do
      before do
        support_worker
        login_as(sw_user)
      end

      it 'updates the report fields and returns 200' do
        put api_visit_report_path(report), params: {
          activities: 'New activity',
          observations: 'New obs',
          follow_up_actions: 'New fup'
        }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['activities']).to eq('New activity')
        expect(body['observations']).to eq('New obs')
        expect(body['follow_up_actions']).to eq('New fup')
      end

      it 'persists the changes to the database' do
        put api_visit_report_path(report), params: { activities: 'Updated', observations: '', follow_up_actions: '' }
        expect(report.reload.activities).to eq('Updated')
      end
    end

    context 'when the report belongs to a different worker' do
      let(:other_approved_user) { User.create!(email: 'other2@test.com', password: 'password123', first_name: 'Carol', last_name: 'Lee', role: 'support_worker') }
      let!(:other_approved_sw) { SupportWorker.create!(user: other_approved_user, first_name: 'Carol', last_name: 'Lee', email: 'other2@test.com', phone: '0422222222', location: 'Brisbane', status: 'approved') }

      before { login_as(other_approved_user) }

      it 'returns 404' do
        put api_visit_report_path(report), params: { activities: 'Hacked' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as a pending support worker' do
      before do
        other_sw
        login_as(other_sw_user)
      end

      it 'returns 403 forbidden' do
        put api_visit_report_path(report), params: { activities: 'Attempted' }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/visit_reports/draft' do
    before do
      support_worker
      login_as(sw_user)
    end

    it 'returns a draft with activities, observations, and follow_up_actions' do
      draft_response = {
        'content' => [{ 'type' => 'text', 'text' => '{"activities":"Helped with cooking","observations":"Client was well","follow_up_actions":"Follow up next week"}' }]
      }
      fake_client = instance_double(Anthropic::Client, messages: draft_response)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)

      post '/api/visit_reports/draft', params: { appointment_id: appointment.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include('activities', 'observations', 'follow_up_actions')
      expect(body['activities']).to eq('Helped with cooking')
    end

    it 'strips markdown code fences from AI response before parsing' do
      fenced = "```json\n{\"activities\":\"Cooking\",\"observations\":\"Well\",\"follow_up_actions\":\"None\"}\n```"
      draft_response = { 'content' => [{ 'type' => 'text', 'text' => fenced }] }
      fake_client = instance_double(Anthropic::Client, messages: draft_response)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)

      post '/api/visit_reports/draft', params: { appointment_id: appointment.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['activities']).to eq('Cooking')
    end

    it 'returns empty fields when AI response is not valid JSON' do
      bad_response = { 'content' => [{ 'type' => 'text', 'text' => 'not json' }] }
      fake_client = instance_double(Anthropic::Client, messages: bad_response)
      allow(Anthropic::Client).to receive(:new).and_return(fake_client)

      post '/api/visit_reports/draft', params: { appointment_id: appointment.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['activities']).to eq('')
      expect(body['observations']).to eq('')
    end

    context 'when session notes exist for the appointment' do
      before do
        AppointmentNote.create!(
          appointment: appointment,
          support_worker_id: support_worker.id,
          content: 'Client completed all exercises. Positive mood. Blood sugar stable.'
        )
      end

      it 'passes session notes to Claude instead of generic appointment context' do
        captured_params = nil
        fake_client = instance_double(Anthropic::Client)
        allow(fake_client).to receive(:messages) do |parameters:|
          captured_params = parameters
          { 'content' => [{ 'type' => 'text', 'text' => '{"activities":"Exercises","observations":"Positive mood","follow_up_actions":"Continue plan"}' }] }
        end
        allow(Anthropic::Client).to receive(:new).and_return(fake_client)

        post '/api/visit_reports/draft', params: { appointment_id: appointment.id }
        expect(response).to have_http_status(:ok)
        prompt_content = captured_params[:messages].first[:content]
        expect(prompt_content).to include('Client completed all exercises')
        expect(prompt_content).not_to include('Health conditions')
      end

      it 'returns the structured draft extracted from session notes' do
        draft_response = { 'content' => [{ 'type' => 'text', 'text' => '{"activities":"Exercises completed","observations":"Positive mood","follow_up_actions":"Continue plan"}' }] }
        fake_client = instance_double(Anthropic::Client, messages: draft_response)
        allow(Anthropic::Client).to receive(:new).and_return(fake_client)

        post '/api/visit_reports/draft', params: { appointment_id: appointment.id }
        body = JSON.parse(response.body)
        expect(body['activities']).to eq('Exercises completed')
      end
    end

    context 'when no session notes exist' do
      it 'falls back to generic appointment context prompt' do
        captured_params = nil
        fake_client = instance_double(Anthropic::Client)
        allow(fake_client).to receive(:messages) do |parameters:|
          captured_params = parameters
          { 'content' => [{ 'type' => 'text', 'text' => '{"activities":"A","observations":"B","follow_up_actions":"C"}' }] }
        end
        allow(Anthropic::Client).to receive(:new).and_return(fake_client)

        post '/api/visit_reports/draft', params: { appointment_id: appointment.id }
        prompt_content = captured_params[:messages].first[:content]
        expect(prompt_content).to include('Health conditions')
        expect(prompt_content).not_to include('Session notes')
      end
    end
  end
end
