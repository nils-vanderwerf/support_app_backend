module Api
  class AppointmentsController < ApplicationController
    def create
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
      render json: appointments
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

    def appointment_params
      params.require(:appointment).permit(:date, :duration, :location, :notes, :client_id, :support_worker_id)
    end
  end
end

