module Api
  class UsersController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_user!

    # Example action to return current user's information
    def show
      if current_user
        render json: { status: 'success', user: current_user }
      else
        render json: { status: 'error', message: 'Not authenticated' }, status: :unauthorized
      end
    end
  end
end