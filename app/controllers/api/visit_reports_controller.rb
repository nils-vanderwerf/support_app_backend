module Api
  class VisitReportsController < ApplicationController
    before_action :require_support_worker

    def index
      worker = current_user.support_worker
      reports = VisitReport.where(support_worker_id: current_user.support_worker.id)
                           .includes(appointment: :client)
                           .order(created_at: :desc)
      render json: reports.as_json(
        include: {
          appointment: {
            include: {
              client: { only: %i[id first_name last_name date_of_birth] }
            }
          }
        }
      )
    end

    def show
      report = VisitReport.find_by(appointment_id: params[:id])
      render json: report
    end

    def create
      report = VisitReport.find_or_initialize_by(appointment_id: params[:appointment_id])
      report.assign_attributes(
        support_worker_id: current_user.support_worker.id,
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

    def update
      report = VisitReport.find_by(id: params[:id], support_worker_id: current_user.support_worker.id)
      return render json: { error: 'Not found' }, status: :not_found unless report

      report.assign_attributes(
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
      session_note = AppointmentNote.find_by(
        appointment_id: appointment.id,
        support_worker_id: current_user.support_worker.id
      )

      prompt = if session_note&.content.present?
        <<~PROMPT
          Extract a structured visit report from these session notes written by the support worker during the appointment.

          Session notes:
          #{session_note.content}

          Session context:
          - Client: #{client.first_name} #{client.last_name}
          - Date: #{appointment.date.strftime('%A %-d %B %Y')}
          - Location: #{appointment.location}

          Populate all three fields from the notes. Each field should be 1–3 sentences. Be professional and concise.
        PROMPT
      else
        <<~PROMPT
          Write a visit report for this session:
          - Client: #{client.first_name} #{client.last_name}
          - Health conditions: #{client.health_conditions.presence || 'none recorded'}
          - Support worker: #{worker.first_name} #{worker.last_name}
          - Date: #{appointment.date.strftime('%A %-d %B %Y')}
          - Duration: #{appointment.duration} minutes
          - Location: #{appointment.location}
          - Notes: #{appointment.notes.presence || 'none'}
        PROMPT
      end

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 512,
        system: 'You are a disability support worker writing a brief post-session visit report. Be professional and concise. Respond ONLY with valid JSON matching this schema exactly: {"activities": "...", "observations": "...", "follow_up_actions": "..."}. No markdown, no extra keys.',
        messages: [{ role: 'user', content: prompt }]
      })

      text = response['content'].find { |b| b['type'] == 'text' }&.fetch('text', '{}')
      text = text.gsub(/\A```(?:json)?\n?/, '').gsub(/\n?```\z/, '').strip
      draft = JSON.parse(text)
      render json: draft
    rescue JSON::ParserError
      render json: { activities: '', observations: '', follow_up_actions: '' }
    end
  end
end
