module Api
  class RegistrationsController < Devise::RegistrationsController
    skip_before_action :verify_authenticity_token

    def create
      puts "Sign up params: #{sign_up_params}"
      user = User.new(sign_up_params)
      if user.save
        render json: { status: 'success', user: user }, status: :created
      else
        render json: { status: 'error', errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def sign_up_params
      params.require(:user).permit(:name, :email, :password)
    end
  end
end