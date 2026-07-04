require 'rails_helper'

RSpec.describe 'ProgressReportsController', type: :request do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Alice', last_name: 'Smith', email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved') }

  let(:other_sw_user) { User.create!(email: 'other@test.com', password: 'password123', first_name: 'Dave', last_name: 'Green', role: 'support_worker') }
  let(:other_worker) { SupportWorker.create!(user: other_sw_user, first_name: 'Dave', last_name: 'Green', email: 'other@test.com', phone: '0433333333', location: 'Melbourne', status: 'approved') }

  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }

  let(:pending_sw_user) { User.create!(email: 'pending@test.com', password: 'password123', first_name: 'Pat', last_name: 'Pending', role: 'support_worker') }
  let(:pending_worker) { SupportWorker.create!(user: pending_sw_user, first_name: 'Pat', last_name: 'Pending', email: 'pending@test.com', phone: '0411111111', location: 'Brisbane', status: 'pending') }

  def login_as(user)
    post api_login_path, params: { email: user.email, password: 'password123' }
  end

  def create_report(worker: nil, client:, summary: 'Good progress.', report_count: 2)
    worker ||= support_worker
    ProgressReport.create!(support_worker_id: worker.id, client: client, summary: summary, report_count: report_count)
  end

  describe 'GET /api/progress_reports' do
    context 'when not logged in' do
      it 'returns forbidden' do
        get '/api/progress_reports'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a client' do
      before { client; login_as(client_user) }

      it 'returns forbidden' do
        get '/api/progress_reports'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a pending support worker' do
      before { pending_worker; login_as(pending_sw_user) }

      it 'returns forbidden' do
        get '/api/progress_reports'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker' do
      before { support_worker; login_as(sw_user) }

      it 'returns an empty array when there are no saved reports' do
        client
        get '/api/progress_reports'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end

      it 'returns their own saved reports with client included' do
        report = create_report(client: client)
        get '/api/progress_reports'
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body.length).to eq(1)
        expect(body.first['id']).to eq(report.id)
        expect(body.first['summary']).to eq('Good progress.')
        expect(body.first['client']).to include('first_name' => 'Jane', 'last_name' => 'Doe')
      end

      it 'does not return reports saved by another worker' do
        other_worker
        create_report(worker: other_worker, client: client)
        get '/api/progress_reports'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end

  describe 'POST /api/progress_reports' do
    context 'when not logged in' do
      it 'returns forbidden' do
        post '/api/progress_reports', params: { client_id: 1, summary: 'Summary', report_count: 1 }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as a client' do
      before { client; login_as(client_user) }

      it 'returns forbidden' do
        post '/api/progress_reports', params: { client_id: client.id, summary: 'Summary', report_count: 1 }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker' do
      before { support_worker; client; login_as(sw_user) }

      it 'creates a progress report and returns 201' do
        expect {
          post '/api/progress_reports', params: { client_id: client.id, summary: 'Great improvement overall.', report_count: 3 }
        }.to change(ProgressReport, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'returns the saved report with client details' do
        post '/api/progress_reports', params: { client_id: client.id, summary: 'Great improvement overall.', report_count: 3 }
        body = JSON.parse(response.body)
        expect(body['summary']).to eq('Great improvement overall.')
        expect(body['report_count']).to eq(3)
        expect(body['client']).to include('first_name' => 'Jane', 'last_name' => 'Doe')
      end

      it 'returns unprocessable_entity when summary is blank' do
        post '/api/progress_reports', params: { client_id: client.id, summary: '', report_count: 0 }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /api/progress_reports/:id' do
    context 'when not logged in' do
      it 'returns forbidden' do
        delete '/api/progress_reports/1'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as an approved support worker' do
      before { support_worker; login_as(sw_user) }

      it 'deletes their own report and returns 204' do
        report = create_report(client: client)
        expect {
          delete "/api/progress_reports/#{report.id}"
        }.to change(ProgressReport, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end

      it 'returns not_found when the report belongs to another worker' do
        other_worker
        other_report = create_report(worker: other_worker, client: client)
        delete "/api/progress_reports/#{other_report.id}"
        expect(response).to have_http_status(:not_found)
      end

      it 'returns not_found for a non-existent report id' do
        delete '/api/progress_reports/99999'
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
