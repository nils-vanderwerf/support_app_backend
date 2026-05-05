module Api
  class SupportWorkersController < ApplicationController
    def index
      render json: SupportWorker.includes(:specializations).all, include: :specializations
    end

    def show
      render json: SupportWorker.includes(:specializations).find(params[:id]), include: :specializations
    end
  end
end