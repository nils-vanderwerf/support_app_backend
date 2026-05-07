module Api
  class AdminController < ApplicationController
    before_action :require_admin

    def applications
      workers = SupportWorker.pending_approval.includes(:user, :specializations)
      render json: workers.as_json(include: { specializations: {}, user: { only: [:email] } },
                                   methods: [:status, :police_check_number, :wwcc_number, :check_notes, :agent_recommendation])
    end

    def approve
      worker = SupportWorker.find(params[:id])
      worker.update!(status: 'approved')
      render json: { message: 'Support worker approved' }
    end

    def reject
      worker = SupportWorker.find(params[:id])
      worker.update!(status: 'rejected')
      render json: { message: 'Support worker rejected' }
    end

    def appointments
      appts = Appointment.includes(:client, :support_worker).order(date: :asc)
      render json: appts.as_json(include: [:client, :support_worker])
    end

    private

    def require_admin
      unless current_user&.is_admin
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
