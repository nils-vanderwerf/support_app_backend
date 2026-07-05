module Api
  class AdminMessagesController < ApplicationController
    skip_worker_approval_check # pending/rejected workers must be able to appeal to admin
    before_action :require_support_worker

    def index
      messages = current_user.support_worker.admin_messages.order(:created_at)
      messages.where(sender: 'admin', read_at: nil).update_all(read_at: Time.current)
      render json: messages.as_json(only: %i[id sender content created_at read_at])
    end

    def create
      msg = current_user.support_worker.admin_messages.create!(
        sender: 'support_worker',
        content: params[:content]
      )
      render json: msg.as_json(only: %i[id sender content created_at]), status: :created
    end
  end
end
