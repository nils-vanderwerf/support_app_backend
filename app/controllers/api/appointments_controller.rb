module Api
  class AppointmentsController < ApplicationController
    def create
      return render json: { errors: 'Must be logged in to book appointments' }, status: :unauthorized unless current_user
      approved_worker = current_user.support_worker&.status == 'approved'
      return render json: { errors: 'Only clients and approved support workers can book appointments' }, status: :forbidden unless current_user.client || approved_worker
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
        Appointment.where(client_id: current_user.client.id, status: 'approved')
                   .where('updated_at > ?', 24.hours.ago)
                   .includes(:client, :support_worker)
      elsif current_user.support_worker
        Appointment.where(support_worker_id: current_user.support_worker.id, status: 'approved')
                   .where('updated_at > ?', 24.hours.ago)
                   .includes(:client, :support_worker)
      else
        []
      end
      render json: appointments.as_json(include: [:client, :support_worker])
    end

    def approve
      appointment = Appointment.find(params[:id])
      appointment.update!(status: 'approved')
      schedule_reminder(appointment)
      post_status_message(appointment, 'approved')
      render json: appointment.as_json(include: [:client, :support_worker])
    end

    def decline
      appointment = Appointment.find(params[:id])
      appointment.update!(status: 'declined')
      post_status_message(appointment, 'declined')
      render json: appointment.as_json(include: [:client, :support_worker])
    end
    
    def update
      appointment = Appointment.find(params[:id])
      if appointment.update(appointment_params)
        schedule_reminder(appointment)
        render json: appointment
      else
        render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      appointment = Appointment.find(params[:id])
      appointment.update(deleted_at: Time.current)
      render json: { message: 'Appointment deleted' }, status: :ok
    end

    private

    def post_status_message(appointment, status)
      return unless appointment.conversation_id

      conversation = Conversation.find(appointment.conversation_id)
      actor = current_user.support_worker || current_user.client
      sender_type = current_user.support_worker ? 'support_worker' : 'client'
      actor_name = "#{actor.first_name} #{actor.last_name}"
      appt_time = appointment.date.strftime('%-d %B at %-I:%M %p') rescue appointment.date.to_s

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
      params.require(:appointment).permit(:date, :duration, :location, :notes, :client_id, :support_worker_id, :status, :conversation_id)
    end
  end
end

