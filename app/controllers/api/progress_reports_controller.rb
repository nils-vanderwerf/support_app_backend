module Api
  class ProgressReportsController < ApplicationController
    before_action :require_support_worker

    def index
      reports = ProgressReport.where(support_worker_id: current_user.support_worker.id)
                              .includes(:client)
                              .order(created_at: :desc)
      render json: reports.as_json(
        include: { client: { only: %i[id first_name last_name] } }
      )
    end

    def create
      report = ProgressReport.create!(
        client_id: params[:client_id],
        support_worker_id: current_user.support_worker.id,
        summary: params[:summary],
        report_count: params[:report_count].to_i
      )
      render json: report.as_json(include: { client: { only: %i[id first_name last_name] } }), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    def destroy
      report = ProgressReport.find_by(id: params[:id], support_worker_id: current_user.support_worker.id)
      return render json: { error: 'Not found' }, status: :not_found unless report
      report.destroy
      head :no_content
    end

    private

    def require_support_worker
      unless current_user&.support_worker&.status == 'approved'
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
