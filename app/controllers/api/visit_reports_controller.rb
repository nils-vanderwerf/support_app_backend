module Api
  class VisitReportsController < ApplicationController
    before_action :require_support_worker

    def index
      worker = current_user.support_worker
      reports = VisitReport.where(user_id: current_user.id)
                           .includes(:appointment)
                           .order(created_at: :desc)
      render json: reports.as_json(include: :appointment)
    end

    def show
      report = VisitReport.find_by(appointment_id: params[:id])
      render json: report
    end

    def create
      report = VisitReport.find_or_initialize_by(appointment_id: params[:appointment_id])
      report.assign_attributes(
        user_id: current_user.id,
        client_id: params[:client_id],
        date: params[:date] || Date.today,
        activities: params[:activities],
        observations: params[:observations],
        follow_up_actions: params[:follow_up_actions]
      )
      if report.save
        render json: report, status: :ok
      else
        render json: { errors: report.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def draft
      appointment = Appointment.includes(:client, :support_worker).find(params[:appointment_id])
      client = appointment.client
      worker = appointment.support_worker

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 512,
        system: 'You are a disability support worker writing a brief post-session visit report. Be professional and concise. Respond ONLY with valid JSON matching this schema exactly: {"activities": "...", "observations": "...", "follow_up_actions": "..."}. No markdown, no extra keys.',
        messages: [{
          role: 'user',
          content: <<~PROMPT
            Write a visit report for this session:
            - Client: #{client.first_name} #{client.last_name}
            - Health conditions: #{client.health_conditions.presence || 'none recorded'}
            - Support worker: #{worker.first_name} #{worker.last_name}
            - Date: #{appointment.date.strftime('%A %-d %B %Y')}
            - Duration: #{appointment.duration} minutes
            - Location: #{appointment.location}
            - Notes: #{appointment.notes.presence || 'none'}
          PROMPT
        }]
      })

      text = response['content'].find { |b| b['type'] == 'text' }&.fetch('text', '{}')
      draft = JSON.parse(text)
      render json: draft
    rescue JSON::ParserError
      render json: { activities: '', observations: '', follow_up_actions: '' }
    end

    private

    def require_support_worker
      unless current_user&.support_worker&.status == 'approved'
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
