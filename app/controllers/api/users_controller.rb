module Api
  class UsersController < ApplicationController
    include RoleRegistry 
    def create
      user = User.new(user_params)
      ActiveRecord::Base.transaction do
        user.save!
        model = ROLE_MODELS[params[:role]]
        raise ActiveRecord::RecordInvalid.new(user), "Invalid role" unless model
        model.create!(role_params.merge(user_id: user.id))
      end
      render json: { message: 'User created successfully', user: user }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.message }, status: :unprocessable_entity
    rescue ActionController::ParameterMissing => e
      render json: { errors: e.message }, status: :bad_request
    end
  
    private

    def user_params
      params.require(:user).permit(:email, :password, :first_name, :last_name, :middle_name)
    end

    def client_params
      params.require(:client).permit(:first_name, :last_name, :middle_name, :age, :gender, :phone, :email, :location, :bio, :health_conditions, :medication, :allergies, :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone)
    end

    def support_worker_params
      params.require(:support_worker).permit(:first_name, :last_name, :middle_name, :age, :gender, :phone, :email, :location, :bio, :experience, :availability, :emergency_contact_first_name, :emergency_contact_last_name, :emergency_contact_phone)
    end

    def role_params
      send("#{ROLE_MODELS[params[:role]].name.underscore}_params")
    end
  end
end
