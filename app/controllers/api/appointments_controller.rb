module Api
  class AppointmentsController < ApplicationController
    # #index deliberately returns an empty list (not 403) for a pending/rejected worker —
    # no client data is exposed either way, and it's an existing, tested contract.
    skip_worker_approval_check :index
    before_action :require_login, only: [:approve, :decline, :bulk_approve, :bulk_decline, :update, :destroy]

    def create
      return render json: { errors: 'Must be logged in to book appointments' }, status: :unauthorized unless current_user
      # WorkerApprovalGate already blocks non-approved workers before this runs.
      return render json: { errors: 'Only clients and approved support workers can book appointments' }, status: :forbidden unless current_user.client || current_user.support_worker
      @appointment = Appointment.new(appointment_params)
      if @appointment.save
        schedule_reminder(@appointment)
        render json: @appointment
      else
        render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def index
      appointments = if current_user.client
        Appointment.approved.where(client_id: current_user.client.id).includes(:client, :support_worker)
      elsif current_user.support_worker&.status == 'approved'
        Appointment.approved.where(support_worker_id: current_user.support_worker.id).includes(:client, :support_worker)
      else
        []
      end
      render json: appointments.as_json(include: [:client, :support_worker])
    end

    def pending
      appointments = if current_user.support_worker
        Appointment.pending.where(support_worker_id: current_user.support_worker.id).includes(:client, :support_worker)
      elsif current_user.client
        Appointment.pending.where(client_id: current_user.client.id).includes(:client, :support_worker)
      else
        []
      end
      render json: appointments.as_json(include: [:client, :support_worker])
    end

    def recently_accepted
      appointments = if current_user.client
        Appointment.active.where(client_id: current_user.client.id, status: 'approved')
                   .where('updated_at > ?', 24.hours.ago)
                   .includes(:client, :support_worker)
      elsif current_user.support_worker
        Appointment.active.where(support_worker_id: current_user.support_worker.id, status: 'approved')
                   .where('updated_at > ?', 24.hours.ago)
                   .includes(:client, :support_worker)
      else
        []
      end
      render json: appointments.as_json(include: [:client, :support_worker])
    end

    def bulk_approve
      ids = Array(params[:appointment_ids])
      appointments = Appointment.where(id: ids, status: 'pending')
                                .select { |appt| party_to_appointment?(appt) }
      ActiveRecord::Base.transaction do
        appointments.each do |appointment|
          appointment.update!(status: 'approved')
          schedule_reminder(appointment)
          post_status_message(appointment, 'approved')
        end
      end
      render json: { approved_count: appointments.count }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def approve
      appointment = Appointment.find(params[:id])
      return unless authorize_appointment!(appointment)
      appointment.update!(status: 'approved')
      schedule_reminder(appointment)
      post_status_message(appointment, 'approved')
      render json: appointment.as_json(include: [:client, :support_worker])
    end

    def decline
      appointment = Appointment.find(params[:id])
      return unless authorize_appointment!(appointment)
      appointment.update!(status: 'declined')
      post_status_message(appointment, 'declined', skip: params[:skip_message])
      render json: appointment.as_json(include: [:client, :support_worker])
    end

    def bulk_decline
      ids = Array(params[:appointment_ids])
      appointments = Appointment.where(id: ids, status: 'pending')
                                .select { |appt| party_to_appointment?(appt) }
      ActiveRecord::Base.transaction do
        appointments.each do |appointment|
          appointment.update!(status: 'declined')
          post_status_message(appointment, 'declined', skip: params[:skip_message])
        end
      end
      render json: { declined_count: appointments.count }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
    
    def update
      appointment = Appointment.find(params[:id])
      return unless authorize_appointment!(appointment)
      if appointment.update(appointment_params)
        schedule_reminder(appointment)
        render json: appointment
      else
        render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      appointment = Appointment.find(params[:id])
      return unless authorize_appointment!(appointment)
      appointment.update(deleted_at: Time.current)
      render json: { message: 'Appointment deleted' }, status: :ok
    end

    private

    def post_status_message(appointment, status, skip: false)
      return unless appointment.conversation_id
      return if ActiveModel::Type::Boolean.new.cast(skip)

      conversation = Conversation.find(appointment.conversation_id)
      actor = current_user.support_worker || current_user.client
      sender_type = current_user.support_worker ? 'support_worker' : 'client'
      tz = timezone_for_location(actor.location)
      appt_time = appointment.date.in_time_zone(tz).strftime('%-d %B at %-I:%M %p') rescue appointment.date.to_s

      text = if status == 'approved'
        "[SYS]✓ Appointment confirmed for #{appt_time}."
      else
        "[SYS] Appointment declined for #{appt_time}."
      end

      conversation.messages.create!(
        content: text,
        sender_type: sender_type,
        sender_id: actor.id
      )
    end

    def schedule_reminder(appointment)
      reminder_time = appointment.date - 24.hours
      return unless reminder_time > Time.current
      AppointmentReminderJob.set(wait_until: reminder_time).perform_later(appointment.id)
    end

    def appointment_params
      params.require(:appointment).permit(:date, :duration, :location, :notes, :client_id, :support_worker_id, :status, :conversation_id, :initiated_by)
    end

    def require_login
      render json: { errors: 'Must be logged in' }, status: :unauthorized unless current_user
    end

    def party_to_appointment?(appointment)
      appointment.client_id == current_user.client&.id ||
        appointment.support_worker_id == current_user.support_worker&.id
    end

    def authorize_appointment!(appointment)
      if party_to_appointment?(appointment)
        true
      else
        render json: { errors: 'Forbidden' }, status: :forbidden
        false
      end
    end
  end
end

