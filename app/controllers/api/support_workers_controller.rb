module Api
  class SupportWorkersController < ApplicationController
    def index
      workers = if current_user&.is_admin
        SupportWorker.includes(:specializations).all
      else
        SupportWorker.includes(:specializations).where(status: 'approved')
      end
      render json: workers.as_json(include: :specializations)
    end

    def show
      worker = SupportWorker.includes(:specializations).find(params[:id])
      unless current_user&.is_admin || worker.status == 'approved'
        return render json: { error: 'Not found' }, status: :not_found
      end
      render json: worker.as_json(include: :specializations)
    end

    def update
      worker = SupportWorker.find(params[:id])
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.support_worker&.id == worker.id
      if worker.update(support_worker_params)
        render json: worker.as_json(include: :specializations, methods: [:age])
      else
        render json: { errors: worker.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def support_worker_params
      params.require(:support_worker).permit(
        :first_name, :last_name, :middle_name, :date_of_birth, :gender, :phone,
        :location, :bio, :experience, :availability, :qualification, :institution, :field_of_study,
        :police_check_expiry, :wwcc_expiry,
        :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone
      )
    end
  end
end