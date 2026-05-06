module Api
  class SupportWorkersController < ApplicationController
    def index
      render json: SupportWorker.includes(:specializations).all, include: :specializations
    end

    def show
      render json: SupportWorker.includes(:specializations).find(params[:id]), include: :specializations
    end

    def update
      worker = SupportWorker.find(params[:id])
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.support_worker&.id == worker.id
      if worker.update(support_worker_params)
        render json: worker, include: :specializations
      else
        render json: { errors: worker.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def support_worker_params
      params.require(:support_worker).permit(
        :first_name, :last_name, :middle_name, :age, :gender, :phone,
        :location, :bio, :experience, :availability,
        :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone
      )
    end
  end
end