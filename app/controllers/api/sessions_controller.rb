module Api
  class SessionsController < ApplicationController
    def create
      user = User.find_by(email: params[:email])
      return render json: { error: "Invalid email or password" }, status: :unauthorized unless user
      if user.valid_password?(params[:password])
        session[:user_id] = user.id
        token = Rails.application.message_verifier(:auth).generate(user.id)
        render json: {
          user: current_user.as_json(only: %i[id email role]),
          client: user.client,
          support_worker: user.support_worker,
          token: token
        }, status: :ok
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end

    def destroy
      session.delete(:user_id)
      render json: { message: 'Logged out' }, status: :ok
    end

    def logged_in_user
      if current_user
        render json: {
            user: current_user.as_json(only: %i[id email role]),
            client: current_user.client,
            support_worker: current_user.support_worker
          }
      else
        render json: { error: "You're not authorized to view this page" }, status: :unauthorized
      end
    end
  end
end