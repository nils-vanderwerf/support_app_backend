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
  end
end