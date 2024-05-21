module Api
  class SupportWorkersController < ApplicationController
    def index
      support_workers = SupportWorker.all
      render json: support_workers
    end

    def show
      support_worker = SupportWorker.find(params[:id])
      render json: support_worker
    end
  end
end