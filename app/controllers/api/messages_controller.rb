module Api
  class MessagesController < ApplicationController
    def index
      conversation = Conversation.find(params[:conversation_id])
      render json: conversation.messages.as_json(only: %i[id content sender_type sender_id created_at])
    end

    def create
      conversation = Conversation.find(params[:conversation_id])
      sender_type = current_user.client ? 'client' : 'support_worker'
      sender_id   = current_user.client&.id || current_user.support_worker&.id
      message = conversation.messages.create!(
        content: params[:content],
        sender_type: sender_type,
        sender_id: sender_id
      )
      render json: message.as_json(only: %i[id content sender_type sender_id created_at]), status: :created
    end
  end
end
