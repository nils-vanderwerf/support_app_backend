module Api
  class UsersController < ApplicationController

    def create
      user = User.new(user_params)
      ActiveRecord::Base.transaction do
        user.save!
        if params[:role] == "client"
          Client.create!(client_params.merge(user_id: user.id))
        elsif params[:role] == "support_worker"
          SupportWorker.create!(support_worker_params.merge(user_id: user.id))
        end
      end
      render json: { message: 'User created successfully', user: user }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.message }, status: :unprocessable_entity
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

  end
end
