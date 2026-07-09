module Api
  class AppointmentNotesController < ApplicationController
    before_action :require_support_worker

    def show
      note = AppointmentNote.find_by(
        appointment_id: params[:appointment_id],
        support_worker_id: current_user.support_worker.id
      )
      return render json: { error: 'Not found' }, status: :not_found unless note
      render json: note
    end

    def create
      appointment = Appointment.find(params[:appointment_id])
      return render json: { error: 'Not found' }, status: :not_found \
        unless appointment.support_worker_id == current_user.support_worker.id

      note = AppointmentNote.find_or_initialize_by(appointment_id: appointment.id)
      note.support_worker_id = current_user.support_worker.id
      note.content = params[:content]

      if note.save
        render json: note, status: :ok
      else
        render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      note = AppointmentNote.find_by(
        appointment_id: params[:appointment_id],
        support_worker_id: current_user.support_worker.id
      )
      return render json: { error: 'Not found' }, status: :not_found unless note

      if note.update(content: params[:content])
        render json: note, status: :ok
      else
        render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
