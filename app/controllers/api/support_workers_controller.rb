module Api
  class SupportWorkersController < ApplicationController
    def index
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.client || current_user&.admin?
      workers = if current_user&.admin?
        SupportWorker.includes(:specialisations).all
      else
        SupportWorker.includes(:specialisations).where(status: 'approved')
      end
      render json: workers.as_json(include: :specialisations, methods: [:age])
    end

    def show
      worker = SupportWorker.includes(:specialisations).find(params[:id])
      is_own_profile = current_user&.support_worker&.id == worker.id
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.client || current_user&.admin? || is_own_profile
      unless current_user&.admin? || worker.status == 'approved' || is_own_profile
        return render json: { error: 'Not found' }, status: :not_found
      end
      render json: worker.as_json(include: :specialisations, methods: %i[age average_rating review_count])
    end

    def update
      worker = SupportWorker.find(params[:id])
      return render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.support_worker&.id == worker.id
      if worker.update(support_worker_params)
        render json: worker.as_json(include: :specialisations, methods: [:age])
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