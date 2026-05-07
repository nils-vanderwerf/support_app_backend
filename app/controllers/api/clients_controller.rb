module Api
  class ClientsController < ApplicationController
    def index
      worker = current_user&.support_worker
      return render json: { error: 'Forbidden' }, status: :forbidden unless worker&.status == 'approved'
      render json: Client.all
    end

    def show
      client = Client.find(params[:id])
      worker = current_user&.support_worker
      approved_worker = worker&.status == 'approved'
      unless approved_worker || current_user&.client&.id == client.id
        return render json: { error: 'Forbidden' }, status: :forbidden
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