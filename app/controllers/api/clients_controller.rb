module Api
  class ClientsController < ApplicationController
    def index
      # WorkerApprovalGate already blocks non-approved workers before this runs.
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.support_worker
      render json: Client.all.as_json(only: Client::PUBLIC_ATTRIBUTES, methods: [:age])
    end

    def show
      client = Client.find(params[:id])
      worker = current_user&.support_worker
      approved_worker = worker&.status == 'approved'
      has_confirmed_appointment = approved_worker && worker.approved_appointment_with?(client)
      if current_user&.client&.id == client.id || has_confirmed_appointment
        render json: client.as_json(methods: [:age]).merge(has_approved_appointment: has_confirmed_appointment)
      elsif approved_worker
        render json: client.as_json_for(full: false).merge(has_approved_appointment: false)
      else
        return render json: { error: 'Forbidden' }, status: :forbidden
      end
    end

    # Every contributing worker's reports for this client are visible to any
    # party with legitimate access (the client themselves, or a worker with
    # their own approved appointment) — not just the requester's own, so a
    # colleague can pick up where another worker left off.
    def visit_reports
      client = Client.find(params[:id])
      return render json: { error: 'Forbidden' }, status: :forbidden unless client_facing_access?(client)

      reports = VisitReport.where(client_id: client.id)
                           .includes(:appointment, :support_worker)
                           .order(date: :desc)
      render json: reports.as_json(
        include: {
          appointment: { only: %i[id date location] },
          support_worker: { only: %i[id first_name last_name] }
        }
      )
    end

    def progress_reports
      client = Client.find(params[:id])
      return render json: { error: 'Forbidden' }, status: :forbidden unless client_facing_access?(client)

      reports = ProgressReport.where(client_id: client.id)
                              .includes(:support_worker)
                              .order(created_at: :desc)
      render json: reports.as_json(
        only: %i[id summary report_count created_at],
        include: { support_worker: { only: %i[id first_name last_name] } }
      )
    end

    def update
      client = Client.find(params[:id])
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.client&.id == client.id
      if client.update(client_params)
        render json: client
      else
        render json: { errors: client.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def client_facing_access?(client)
      worker = current_user&.support_worker
      current_user&.client&.id == client.id ||
        (worker&.status == 'approved' && worker.approved_appointment_with?(client))
    end

    def client_params
      params.require(:client).permit(
        :first_name, :last_name, :middle_name, :date_of_birth, :gender, :phone,
        :location, :bio, :health_conditions, :medication, :allergies,
        :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone
      )
    end
  end
end
