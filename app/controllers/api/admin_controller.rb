module Api
  class AdminController < ApplicationController
    skip_worker_approval_check # admins are never gated by their own worker-approval status
    before_action :require_admin

    def applications
      workers = SupportWorker.pending_approval.includes(:user, :specialisations)
      render json: workers.as_json(include: { specialisations: {}, user: { only: [:email] } },
                                   methods: [:status, :police_check_number, :wwcc_number, :check_notes, :agent_recommendation])
    end

    def approve
      worker = SupportWorker.find(params[:id])
      worker.update!(status: 'approved', approved_by_id: current_user.id, admin_note: params[:note])
      note_text = params[:note].present? ? "\n\n#{params[:note]}" : ''
      worker.admin_messages.create!(
        sender: 'admin',
        content: "🎉 Your application has been approved! Welcome to Suppova.#{note_text}"
      )
      render json: { message: 'Support worker approved' }
    end

    def reject
      worker = SupportWorker.find(params[:id])
      worker.update!(status: 'rejected', rejected_at: Time.current, admin_note: params[:note])
      note_text = params[:note].present? ? "\n\n#{params[:note]}" : ''
      worker.admin_messages.create!(
        sender: 'admin',
        content: "Your application was not approved at this time.#{note_text}\n\nYou're welcome to reapply after 3 days. A link to reapply will appear in this thread once the waiting period is over."
      )
      render json: { message: 'Support worker rejected' }
    end

    def messages
      threads = SupportWorker.joins(:admin_messages)
                             .select('support_workers.*, COUNT(admin_messages.id) AS message_count')
                             .where(admin_messages: { sender: 'support_worker', read_at: nil })
                             .group('support_workers.id')
                             .order('message_count DESC')
      all_workers_with_messages = SupportWorker.joins(:admin_messages).distinct
      render json: all_workers_with_messages.map { |w|
        {
          support_worker: { id: w.id, first_name: w.first_name, last_name: w.last_name, email: w.email },
          messages: w.admin_messages.order(:created_at).as_json(only: %i[id sender content created_at read_at]),
          unread_count: w.admin_messages.where(sender: 'support_worker', read_at: nil).count
        }
      }
    end

    def reply_message
      worker = SupportWorker.find(params[:support_worker_id])
      worker.admin_messages.where(sender: 'support_worker', read_at: nil).update_all(read_at: Time.current)
      msg = worker.admin_messages.create!(sender: 'admin', content: params[:content])
      render json: msg.as_json(only: %i[id sender content created_at]), status: :created
    end

    def appointments
      worker_ids = SupportWorker.where(approved_by_id: current_user.id).pluck(:id)
      appts = Appointment.active.where(support_worker_id: worker_ids).includes(:client, :support_worker).order(date: :asc)
      render json: appts.as_json(include: [:client, :support_worker])
    end

    def workers
      workers = SupportWorker.where(status: 'approved', approved_by_id: current_user.id).includes(:user, :specialisations)
      render json: workers.as_json(include: { specialisations: {}, user: { only: [:email] } })
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
        unread_messages: AdminMessage.where(sender: 'support_worker', read_at: nil).count,
      }
    end

    private

    def require_admin
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
      render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
    end
  end
end
