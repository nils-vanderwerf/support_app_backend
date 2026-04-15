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
      appointments = Appointment.all
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

