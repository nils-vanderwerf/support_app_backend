module Api
  class AiBookingController < ApplicationController
    def chat
      return render json: { error: 'Must be logged in' }, status: :unauthorized unless current_user

      profile = current_user.client || current_user.support_worker
      return render json: { error: 'No profile found' }, status: :forbidden unless profile

      is_client = current_user.client.present?
      messages  = params[:messages].map { |m| { role: m[:role], content: m[:content] } }
      timezone  = params[:timezone].presence || 'UTC'

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])

      loop do
        response = anthropic.messages(parameters: {
          model:     'claude-sonnet-4-6',
          max_tokens: 1024,
          system:    system_prompt(profile, is_client, timezone),
          messages:  messages,
          tools:     booking_tools(is_client, timezone)
        })

        tool_uses = response['content'].select { |b| b['type'] == 'tool_use' }

        if tool_uses.any?
          tool_results = tool_uses.map { |tu| execute_tool(tu, profile, is_client) }
          messages = messages + [
            { role: 'assistant', content: response['content'] },
            { role: 'user',      content: tool_results }
          ]
        else
          text = response['content'].find { |b| b['type'] == 'text' }&.fetch('text', '')
          return render json: { message: text }
        end
      end
    end

    private

    def system_prompt(profile, is_client, timezone)
      if is_client
        <<~PROMPT
          You are a friendly AI booking assistant for a disability support platform.
          You help clients find and book appointments with support workers.

          The client you are assisting:
          - Name: #{profile.first_name} #{profile.last_name}
          - Health conditions: #{profile.health_conditions.presence || 'None recorded'}
          - Medication: #{profile.medication.presence || 'None recorded'}
          - Allergies: #{profile.allergies.presence || 'None recorded'}
          - Location: #{profile.location.presence || 'Not specified'}

          When booking:
          1. Understand what the client needs
          2. Call get_support_workers to find suitable workers
          3. Present 2-3 options with a brief reason each is a good match
          4. Once the client selects a worker and provides a date, time and duration, call create_appointment
          5. Confirm the booking details to the client

          Be warm, concise and professional. Today's date is #{Date.today}.
          The client's timezone is #{timezone}. Always include the UTC offset in the ISO 8601 datetime.
        PROMPT
      else
        <<~PROMPT
          You are a friendly AI booking assistant for a disability support platform.
          You help support workers find and book appointments with clients.

          The support worker you are assisting:
          - Name: #{profile.first_name} #{profile.last_name}
          - Specializations: #{profile.specializations.map(&:name).join(', ').presence || 'None recorded'}
          - Location: #{profile.location.presence || 'Not specified'}

          When booking:
          1. Understand which client they want to book with or what kind of client they are looking for
          2. Call get_clients to find suitable clients
          3. Once they select a client and provide a date, time and duration, call create_appointment
          4. Confirm the booking details

          Be warm, concise and professional. Today's date is #{Date.today}.
          The support worker's timezone is #{timezone}. Always include the UTC offset in the ISO 8601 datetime.
        PROMPT
      end
    end

    def booking_tools(is_client, timezone = 'UTC')
      offset_example = '+10:00'
      date_desc = "ISO 8601 datetime with UTC offset for the user's timezone (#{timezone}), e.g. 2026-05-12T09:00:00#{offset_example}"

      if is_client
        [
          {
            name: 'get_support_workers',
            description: 'Fetch available support workers, including name, bio, experience, specializations, availability and location.',
            input_schema: {
              type: 'object',
              properties: {
                keyword: { type: 'string', description: 'Optional keyword to filter by (searches bio, experience and specializations)' }
              }
            }
          },
          {
            name: 'create_appointment',
            description: 'Book an appointment between the current client and a support worker.',
            input_schema: {
              type: 'object',
              properties: {
                support_worker_id: { type: 'integer', description: 'ID of the support worker to book' },
                date:              { type: 'string',  description: date_desc },
                duration:          { type: 'integer', description: 'Duration in minutes' },
                location:          { type: 'string',  description: 'Location of the appointment' },
                notes:             { type: 'string',  description: 'Optional notes' }
              },
              required: %w[support_worker_id date duration location]
            }
          }
        ]
      else
        [
          {
            name: 'get_clients',
            description: 'Fetch clients, including name, health conditions, location and contact info.',
            input_schema: {
              type: 'object',
              properties: {
                keyword: { type: 'string', description: 'Optional keyword to filter clients by name or health conditions' }
              }
            }
          },
          {
            name: 'create_appointment',
            description: 'Book an appointment between the current support worker and a client.',
            input_schema: {
              type: 'object',
              properties: {
                client_id: { type: 'integer', description: 'ID of the client to book' },
                date:      { type: 'string',  description: date_desc },
                duration:  { type: 'integer', description: 'Duration in minutes' },
                location:  { type: 'string',  description: 'Location of the appointment' },
                notes:     { type: 'string',  description: 'Optional notes' }
              },
              required: %w[client_id date duration location]
            }
          }
        ]
      end
    end

    def execute_tool(tool_use, profile, is_client)
      result = case tool_use['name']
               when 'get_support_workers' then run_get_support_workers(tool_use['input']['keyword'])
               when 'get_clients'         then run_get_clients(tool_use['input']['keyword'])
               when 'create_appointment'  then run_create_appointment(tool_use['input'], profile, is_client)
               else { error: "Unknown tool: #{tool_use['name']}" }
               end

      { type: 'tool_result', tool_use_id: tool_use['id'], content: result.to_json }
    end

    def run_get_support_workers(keyword)
      workers = SupportWorker.includes(:specializations).all
      if keyword.present?
        kw = keyword.downcase
        workers = workers.select do |w|
          [w.bio, w.experience, w.specializations.map(&:name).join(' ')].any? { |f| f.to_s.downcase.include?(kw) }
        end
      end
      workers.map do |w|
        { id: w.id, name: "#{w.first_name} #{w.last_name}", bio: w.bio, experience: w.experience,
          specializations: w.specializations.map(&:name), availability: w.availability, location: w.location }
      end
    end

    def run_get_clients(keyword)
      clients = Client.all
      if keyword.present?
        kw = keyword.downcase
        clients = clients.select do |c|
          ["#{c.first_name} #{c.last_name}", c.health_conditions.to_s].any? { |f| f.downcase.include?(kw) }
        end
      end
      clients.map do |c|
        { id: c.id, name: "#{c.first_name} #{c.last_name}", location: c.location,
          health_conditions: c.health_conditions, phone: c.phone }
      end
    end

    def run_create_appointment(input, profile, is_client)
      attrs = {
        date:     input['date'],
        duration: input['duration'],
        location: input['location'],
        notes:    input['notes']
      }
      attrs[:client_id]         = is_client ? profile.id : input['client_id']
      attrs[:support_worker_id] = is_client ? input['support_worker_id'] : profile.id

      appointment = Appointment.new(attrs)
      if appointment.save
        { success: true, appointment_id: appointment.id }
      else
        { success: false, errors: appointment.errors.full_messages }
      end
    end
  end
end
