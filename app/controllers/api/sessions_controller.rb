module Api
  class SessionsController < ApplicationController
    def create
      user = User.find_by(email: params[:email])
      return render json: { error: "Invalid email or password" }, status: :unauthorized unless user
      if user.valid_password?(params[:password])
        session[:user_id] = user.id       
        render json: {
          user: user,
          client: user.client,
          support_worker: user.support_worker
        }, status: :ok
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end
  end
end