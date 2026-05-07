module Api
  class NotificationsController < ApplicationController
    def index
      if current_user.client
        person = current_user.client
        role = 'client'
        other_role = 'support_worker'
      elsif current_user.support_worker
        person = current_user.support_worker
        role = 'support_worker'
        other_role = 'client'
      else
        return render json: { unread_messages: 0, pending_invitations: 0, total: 0 }
      end

      conversations = if role == 'client'
        Conversation.where(client_id: person.id).includes(:messages)
      else
        Conversation.where(support_worker_id: person.id).includes(:messages)
      end

      unread = conversations.count do |conv|
        last = conv.messages.sort_by(&:created_at).last
        last && last.sender_type == other_role
      end

      pending_invitations = if role == 'support_worker'
        Appointment.where(support_worker_id: person.id, status: 'pending').count
      else
        Appointment.where(client_id: person.id, status: 'pending').count
      end

      recently_accepted = if role == 'client'
        Appointment.where(client_id: person.id, status: 'approved')
                   .where('updated_at > ?', 24.hours.ago).count
      else
        0
      end

      render json: {
        unread_messages: unread,
        pending_invitations: pending_invitations,
        recently_accepted: recently_accepted,
        total: unread + pending_invitations + recently_accepted,
      }
    end
  end
end
