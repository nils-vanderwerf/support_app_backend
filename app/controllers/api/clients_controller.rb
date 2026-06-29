module Api
  class ClientsController < ApplicationController
    def index
      worker = current_user&.support_worker
      return render json: { error: 'Forbidden' }, status: :forbidden unless worker&.status == 'approved'
      render json: Client.all.as_json(only: [:id, :first_name, :last_name, :location, :health_conditions], methods: [:age])
    end

    def show
      client = Client.find(params[:id])
      worker = current_user&.support_worker
      approved_worker = worker&.status == 'approved'
      has_confirmed_appointment = Appointment.where(support_worker_id: worker&.id, client_id: client.id).approved.present?
      if current_user&.client&.id == client.id || (approved_worker && has_confirmed_appointment)
        render json: client.as_json(methods: [:age]).merge(has_approved_appointment: has_confirmed_appointment)
      elsif approved_worker && !has_confirmed_appointment
        render json: client.as_json(only: [:id, :first_name, :last_name, :location, :bio, :health_conditions]).merge(has_approved_appointment: false)
      else
        return render json: { error: 'Forbidden' }, status: :forbidden
      end
    end

    def visit_reports
      client = Client.find(params[:id])

      if current_user&.client&.id == client.id
        reports = VisitReport.where(client_id: client.id)
                             .includes(:appointment, :support_worker)
                             .order(date: :desc)
        render json: reports.as_json(
          include: {
            appointment: { only: %i[id date location] },
            support_worker: { only: %i[id first_name last_name] }
          }
        )
      elsif current_user&.support_worker&.status == 'approved'
        worker = current_user.support_worker
        unless Appointment.where(support_worker_id: worker.id, client_id: client.id).approved.exists?
          return render json: { error: 'Forbidden' }, status: :forbidden
        end
        reports = VisitReport.where(client_id: client.id, user_id: current_user.id)
                             .includes(:appointment)
                             .order(date: :desc)
        render json: reports.as_json(include: { appointment: { only: %i[id date location] } })
      else
        render json: { error: 'Forbidden' }, status: :forbidden
      end
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

    def client_params
      params.require(:client).permit(
        :first_name, :last_name, :middle_name, :date_of_birth, :gender, :phone,
        :location, :bio, :health_conditions, :medication, :allergies,
        :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone
      )
    end
  end
end
