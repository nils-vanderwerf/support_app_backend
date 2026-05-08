require 'rails_helper'

RSpec.describe 'VisitReportsController', type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Alice', last_name: 'Smith', email: 'sw@test.com', phone: '0400000000', age: 30, location: 'Sydney', status: 'approved') }
  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:appointment) { Appointment.create!(client: client, support_worker: support_worker, date: 1.day.ago) }

  let(:other_sw_user) { User.create!(email: 'other_sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Jones', role: 'support_worker') }
  let(:other_sw) { SupportWorker.create!(user: other_sw_user, first_name: 'Bob', last_name: 'Jones', email: 'other_sw@test.com', phone: '0411111111', age: 28, location: 'Melbourne', status: 'pending') }

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
        VisitReport.create!(user_id: sw_user.id, client_id: client.id, appointment_id: appointment.id,
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
      VisitReport.create!(user_id: sw_user.id, client_id: client.id, appointment_id: appointment.id,
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
  end
end
