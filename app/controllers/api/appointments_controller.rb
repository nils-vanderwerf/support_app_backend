module Api
  class AppointmentsController < ApplicationController
    def create
      return render json: { errors: 'Must be logged in to book appointments' }, status: :unauthorized unless current_user
      return render json: { errors: 'Only clients and support workers can book appointments' }, status: :forbidden unless current_user.client || current_user.support_worker

      @appointment = Appointment.new(appointment_params)
    if @appointment.save
        render json: @appointment
      else
        render json: { errors: @appointment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def index
      appointments = if current_user.client
        Appointment.where(client_id: current_user.client.id)
      elsif current_user.support_worker
        Appointment.where(support_worker_id: current_user.support_worker.id)
      else
        []
      end
      render json: appointments, include: [:client, :support_worker]
    end
    
    def update
      appointment = Appointment.find(params[:id])
      if appointment.update(appointment_params)
        render json: appointment
      else
        render json: { errors: appointment.errors.full_messages }, status: :unprocessable_entity
      end 
    end

    def destroy
      appointment = Appointment.find(params[:id])
      appointment.destroy
      render json: { message: 'Appointment deleted' }, status: :ok
    end

    private

    def post_status_message(appointment, status)
      return unless appointment.conversation_id

      conversation = Conversation.find(appointment.conversation_id)
      actor = current_user.support_worker || current_user.client
      sender_type = current_user.support_worker ? 'support_worker' : 'client'
      tz = ActiveSupport::TimeZone[params[:timezone].to_s] || Time.zone
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
      params.require(:appointment).permit(:date, :duration, :location, :notes, :client_id, :support_worker_id)
    end
  end
end