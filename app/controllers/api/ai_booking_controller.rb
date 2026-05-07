module Api
  class AiBookingController < ApplicationController
    def chat
      return render json: { error: 'Must be logged in' }, status: :unauthorized unless current_user

      profile = current_user.client || current_user.support_worker
      return render json: { error: 'No profile found' }, status: :forbidden unless profile

      is_client = current_user.client.present?
      messages  = params[:messages].map { |m| { role: m[:role], content: m[:content] } }
      timezone  = params[:timezone].presence || 'UTC'

      @conversation_id = nil
      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])

      loop do
        response = anthropic.messages(parameters: {
          model:      'claude-sonnet-4-6',
          max_tokens: 1024,
          system:     system_prompt(profile, is_client, timezone),
          messages:   messages,
          tools:      booking_tools(is_client, timezone)
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
          return render json: { message: text, conversation_id: @conversation_id }
        end
      end
    end

    private

    def system_prompt(profile, is_client, timezone)
      if is_client
        <<~PROMPT
          You are a friendly AI booking assistant for a disability support platform.
          You help clients find support workers and send them appointment invitations.

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
          4. Once the client selects a worker, call open_conversation to start a chat with them
          5. Let the client know they've been connected and can now chat and send an invitation directly from the conversation

          Be warm, concise and professional. Today's date is #{Date.today}.
        PROMPT
      else
        <<~PROMPT
          You are a friendly AI booking assistant for a disability support platform.
          You help support workers find clients and connect with them.

          The support worker you are assisting:
          - Name: #{profile.first_name} #{profile.last_name}
          - Specializations: #{profile.specializations.map(&:name).join(', ').presence || 'None recorded'}
          - Location: #{profile.location.presence || 'Not specified'}

          When booking:
          1. Understand which client they want to connect with or what kind of client they are looking for
          2. Call get_clients to find suitable clients
          3. Once they select a client, call open_conversation to start a chat with them
          4. Let the support worker know they've been connected and can now message and send an invitation from the chat

          Be warm, concise and professional. Today's date is #{Date.today}.
        PROMPT
      end
    end

    def booking_tools(is_client, _timezone = 'UTC')
      open_conv_tool = {
        name: 'open_conversation',
        description: 'Open a conversation with the selected person. Call this once the user has chosen who they want to connect with. This will take the user directly to the chat.',
        input_schema: {
          type: 'object',
          properties: {
            person_id: { type: 'integer', description: is_client ? 'ID of the support worker to connect with' : 'ID of the client to connect with' }
          },
          required: %w[person_id]
        }
      }

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
          open_conv_tool
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
          open_conv_tool
        ]
      end
    end

    def execute_tool(tool_use, profile, is_client)
      result = case tool_use['name']
               when 'get_support_workers' then run_get_support_workers(tool_use['input']['keyword'])
               when 'get_clients'         then run_get_clients(tool_use['input']['keyword'])
               when 'open_conversation'   then run_open_conversation(tool_use['input']['person_id'], profile, is_client)
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

    def run_open_conversation(person_id, profile, is_client)
      client_id         = is_client ? profile.id : person_id
      support_worker_id = is_client ? person_id   : profile.id

      conversation = Conversation.find_or_create_by(
        client_id: client_id,
        support_worker_id: support_worker_id
      )
      @conversation_id = conversation.id

      { success: true, conversation_id: conversation.id }
    end
  end
end
