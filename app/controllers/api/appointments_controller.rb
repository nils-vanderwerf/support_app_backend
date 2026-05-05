module Api
  class AppointmentsController < ApplicationController
    before_action :require_login, only: [:approve, :decline, :bulk_approve, :update, :destroy]

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
      post_status_message(appointment, 'declined')
      render json: appointment.as_json(include: [:client, :support_worker])
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

