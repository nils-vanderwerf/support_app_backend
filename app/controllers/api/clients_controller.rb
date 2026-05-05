module Api
  class ClientsController < ApplicationController
    def index
      worker = current_user&.support_worker
      return render json: { error: 'Forbidden' }, status: :forbidden unless worker&.status == 'approved'
      render json: Client.all.as_json(only: [:id, :first_name, :last_name, :age, :location, :health_conditions])
    end

    def show
      client = Client.find(params[:id])
      worker = current_user&.support_worker
      approved_worker = worker&.status == 'approved'
      has_confirmed_appointment = Appointment.where(support_worker_id: worker&.id, client_id: client.id).approved.present?
      if current_user&.client&.id == client.id || (approved_worker && has_confirmed_appointment)
        render json: client
      elsif approved_worker && !has_confirmed_appointment
        render json: client.as_json(only: [:id, :first_name, :last_name, :location, :bio, :health_conditions])
      else
        return render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end