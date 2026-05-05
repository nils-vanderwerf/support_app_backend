module Api
  class AiBookingController < ApplicationController
    def chat
      return render json: { error: 'Must be logged in' }, status: :unauthorized unless current_user
      return render json: { error: 'Only clients can use the booking agent' }, status: :forbidden unless current_user.client

      client_record = current_user.client
      messages = params[:messages].map { |m| { role: m[:role], content: m[:content] } }

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])

      loop do
        response = anthropic.messages(parameters: {
          model: 'claude-sonnet-4-6',
          max_tokens: 1024,
          system: system_prompt(client_record),
          messages: messages,
          tools: booking_tools
        })

        tool_uses = response['content'].select { |b| b['type'] == 'tool_use' }

        if tool_uses.any?
          tool_results = tool_uses.map { |tu| execute_tool(tu, client_record) }

          messages = messages + [
            { role: 'assistant', content: response['content'] },
            { role: 'user', content: tool_results }
          ]
        else
          text = response['content'].find { |b| b['type'] == 'text' }&.fetch('text', '')
          return render json: { message: text }
        end
      end
    end

    private

    def system_prompt(client)
      <<~PROMPT
        You are a friendly AI booking assistant for a disability support platform.
        You help clients find and book appointments with support workers.

        The client you are assisting:
        - Name: #{client.first_name} #{client.last_name}
        - Health conditions: #{client.health_conditions.presence || 'None recorded'}
        - Medication: #{client.medication.presence || 'None recorded'}
        - Allergies: #{client.allergies.presence || 'None recorded'}
        - Location: #{client.location.presence || 'Not specified'}

        When booking:
        1. Understand what the client needs
        2. Call get_support_workers to find suitable workers
        3. Present 2-3 options with a brief reason each is a good match
        4. Once the client selects a worker and provides a date, time and duration, call create_appointment
        5. Confirm the booking details to the client

        Be warm, concise and professional. Today's date is #{Date.today}.
      PROMPT
    end

    def booking_tools
      [
        {
          name: 'get_support_workers',
          description: 'Fetch available support workers, including their name, bio, experience, specializations, availability and location.',
          input_schema: {
            type: 'object',
            properties: {
              keyword: {
                type: 'string',
                description: 'Optional keyword to filter workers by (searches bio, experience and specializations)'
              }
            }
          }
        },
        {
          name: 'create_appointment',
          description: 'Book an appointment with a support worker for the current client.',
          input_schema: {
            type: 'object',
            properties: {
              support_worker_id: { type: 'integer', description: 'ID of the support worker to book' },
              date: { type: 'string', description: 'ISO 8601 datetime, e.g. 2026-05-12T09:00:00' },
              duration: { type: 'integer', description: 'Duration in minutes' },
              location: { type: 'string', description: 'Location of the appointment' },
              notes: { type: 'string', description: 'Optional notes about the visit' }
            },
            required: %w[support_worker_id date duration location]
          }
        }
      ]
    end

    def execute_tool(tool_use, client)
      result = case tool_use['name']
               when 'get_support_workers'
                 run_get_support_workers(tool_use['input']['keyword'])
               when 'create_appointment'
                 run_create_appointment(tool_use['input'], client)
               else
                 { error: "Unknown tool: #{tool_use['name']}" }
               end

      { type: 'tool_result', tool_use_id: tool_use['id'], content: result.to_json }
    end

    def run_get_support_workers(keyword)
      workers = SupportWorker.includes(:specializations).all
      if keyword.present?
        kw = keyword.downcase
        workers = workers.select do |w|
          [w.bio, w.experience, w.specializations.map(&:name).join(' ')].any? do |field|
            field.to_s.downcase.include?(kw)
          end
        end
      end

      workers.map do |w|
        {
          id: w.id,
          name: "#{w.first_name} #{w.last_name}",
          bio: w.bio,
          experience: w.experience,
          specializations: w.specializations.map(&:name),
          availability: w.availability,
          location: w.location
        }
      end
    end

    def run_create_appointment(input, client)
      appointment = Appointment.new(
        client_id: client.id,
        support_worker_id: input['support_worker_id'],
        date: input['date'],
        duration: input['duration'],
        location: input['location'],
        notes: input['notes']
      )

      if appointment.save
        { success: true, appointment_id: appointment.id }
      else
        { success: false, errors: appointment.errors.full_messages }
      end
    end
  end
end
