module Api
  class SessionsController < ApplicationController
    def create
      user = User.find_by(email: params[:email])
      return render json: { error: "Invalid email or password" }, status: :unauthorized unless user
      if user.valid_password?(params[:password])
       render json: { success: user }
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end

    def logged_in_user
      if current_user
        render json: {
            user: current_user,
            client: current_user.client,
            support_worker: current_user.support_worker
          }
      else
        render json: { error: "You're not authorized to view this page" }, status: :unauthorized
      end
    end
  end
end