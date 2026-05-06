module Api
  class ClientsController < ApplicationController
    def index
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.support_worker
      render json: Client.all
    end

    def show
      client = Client.find(params[:id])
      unless current_user&.support_worker || current_user&.client&.id == client.id
        return render json: { error: 'Forbidden' }, status: :forbidden
      end
      render json: client
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
        :first_name, :last_name, :middle_name, :age, :gender, :phone,
        :location, :bio, :health_conditions, :medication, :allergies,
        :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone
      )
    end
  end
end
