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
      worker.update!(status: 'approved', approved_by_id: current_user.id)
      render json: { message: 'Support worker approved' }
    end

    def reject
      worker = SupportWorker.find(params[:id])
      worker.update!(status: 'rejected')
      render json: { message: 'Support worker rejected' }
    end

    def appointments
      worker_ids = SupportWorker.where(approved_by_id: current_user.id).pluck(:id)
      appts = Appointment.active.where(support_worker_id: worker_ids).includes(:client, :support_worker).order(date: :asc)
      render json: appts.as_json(include: [:client, :support_worker])
    end

    def workers
      workers = SupportWorker.where(status: 'approved', approved_by_id: current_user.id).includes(:user, :specializations)
      render json: workers.as_json(include: { specializations: {}, user: { only: [:email] } })
    end

    def stats
      worker_ids = SupportWorker.where(approved_by_id: current_user.id).pluck(:id)
      render json: {
        approved_workers: SupportWorker.where(status: 'approved', approved_by_id: current_user.id).count,
        pending_workers:  SupportWorker.pending_approval.count,
        total_clients: Client.joins(:appointments)
          .where(appointments: { support_worker_id: worker_ids })
          .distinct.count,
        appointments_this_week: Appointment.active
          .where(support_worker_id: worker_ids)
          .where(date: Time.current.beginning_of_week..Time.current.end_of_week)
          .count,
      }
    end

    private

    def require_admin
      unless current_user&.admin?
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
