module Api
  class AppointmentsController < ApplicationController
    def create
      return render json: { errors: 'Must be logged in to book appointments' }, status: :unauthorized unless current_user
      return render json: { errors: 'Only clients and support workers can book appointments' }, status: :forbidden unless current_user.client || current_user.support_worker
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
        Appointment.active.where(client_id: current_user.client.id)
      elsif current_user.support_worker
        Appointment.active.where(support_worker_id: current_user.support_worker.id)
      else
        []
      end
      render json: appointments, include: [:client, :support_worker]
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

