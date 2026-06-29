module Api
  class ClientProgressReportsController < ApplicationController
    before_action :require_support_worker

    def create
      client = Client.find_by(id: params[:client_id])
      return render json: { error: 'Client not found' }, status: :not_found unless client

      worker = current_user.support_worker
      unless Appointment.where(support_worker_id: worker.id, client_id: client.id).approved.exists?
        return render json: { error: 'Forbidden' }, status: :forbidden
      end

      reports = VisitReport.joins(:appointment)
                           .where(appointments: { client_id: client.id })
                           .includes(:appointment)
                           .order('appointments.date ASC')

      if reports.empty?
        return render json: {
          summary: "No visit reports have been recorded for #{client.first_name} #{client.last_name} yet.",
          report_count: 0
        }
      end

      reports_text = reports.map.with_index(1) do |r, i|
        appt_date = r.appointment.date.strftime('%-d %B %Y')
        <<~REPORT
          Visit #{i} (#{appt_date}):
          Activities: #{r.activities.presence || 'not recorded'}
          Observations: #{r.observations.presence || 'not recorded'}
          Follow-up actions: #{r.follow_up_actions.presence || 'none'}
        REPORT
      end.join("\n")

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 1024,
        system: 'You are a disability support coordinator writing a concise progress summary for a client. Be professional and compassionate. Use markdown formatting with ## headers.',
        messages: [{
          role: 'user',
          content: <<~PROMPT
            Write a progress summary for this client based on #{reports.count} visit report(s).

            Client: #{client.first_name} #{client.last_name}
            Health conditions: #{client.health_conditions.presence || 'none recorded'}

            Visit reports (chronological):
            #{reports_text}

            Structure your summary with these sections:
            ## Overall Progress
            ## Recurring Observations or Concerns
            ## Outstanding Follow-up Actions
            ## Recommendations
          PROMPT
        }]
      })

      summary = response['content'].find { |b| b['type'] == 'text' }&.fetch('text', '')
      render json: { summary: summary, report_count: reports.count }
    end

    private

    def require_support_worker
      unless current_user&.support_worker&.status == 'approved'
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
