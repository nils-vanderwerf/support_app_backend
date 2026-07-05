module Api
  class AiBookingController < ApplicationController
    def chat
      return render json: { error: 'Must be logged in' }, status: :unauthorized unless current_user

      # WorkerApprovalGate already blocks non-approved workers before this runs.
      profile = current_user.client || current_user.support_worker
      return render json: { error: 'No profile found' }, status: :forbidden unless profile

      is_client = current_user.client.present?
      messages  = params[:messages].map { |m| { role: m[:role], content: m[:content] } }
      timezone  = params[:timezone].presence || 'UTC'

      @conversation_id = nil
      all_tool_calls   = []
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
          tool_uses.each { |tu| all_tool_calls << { name: tu['name'], input: tu['input'] } }
          tool_results = tool_uses.map { |tu| execute_tool(tu, profile, is_client) }
          messages = messages + [
            { role: 'assistant', content: response['content'] },
            { role: 'user',      content: tool_results }
          ]
        else
          text = response['content'].find { |b| b['type'] == 'text' }&.fetch('text', '')
          return render json: { message: text, conversation_id: @conversation_id, tool_calls: all_tool_calls }
        end
      end
    end

    private

    def system_prompt(profile, is_client, timezone)
      if is_client
        client_location    = profile.location.presence || 'Not specified'
        client_needs       = profile.health_conditions.presence || 'None recorded'
        <<~PROMPT
          You are a friendly AI booking assistant for a disability support platform.
          You help clients find support workers and send them appointment invitations.

          The client you are assisting:
          - Name: #{profile.first_name} #{profile.last_name}
          - Location: #{client_location}
          - Health conditions / needs: #{client_needs}
          - Medication: #{profile.medication.presence || 'None recorded'}
          - Allergies: #{profile.allergies.presence || 'None recorded'}

          When finding and recommending support workers, you MUST apply these two checks:

          1. DISTANCE CHECK — The client is in #{client_location}.
             Use your geographic knowledge to assess distance.
             If a worker is more than ~100km away (e.g. a different city or state), flag this clearly:
             tell the client the worker is too far away and skip or deprioritise them.
             Only recommend local or nearby workers unless the client explicitly asks for remote options.

          2. SPECIALIZATION FIT — The client's needs are: #{client_needs}.
             Only recommend workers whose specialisations genuinely match these needs.
             If a worker's specialisations are unrelated, say so and move on.
             If no workers are a good fit, say so honestly rather than forcing a recommendation.

          When presenting options, always state: why each worker is a good location and specialisation match.
          If you push back on a worker due to distance or poor fit, briefly explain why.

          Workflow:
          1. Understand what the client needs (clarify if vague)
          2. Call get_support_workers to find candidates
          3. Apply distance and specialisation checks — only present suitable workers
          4. Once the client selects a worker, call open_conversation
          5. Let them know they can chat and send an invitation from the conversation

          Be warm, concise and professional. Today's date is #{Date.today}.
        PROMPT
      else
        sw_location        = profile.location.presence || 'Not specified'
        sw_specialisations = profile.specialisations.map(&:name).join(', ').presence || 'None recorded'
        <<~PROMPT
          You are a friendly AI booking assistant for a disability support platform.
          You help support workers find clients and connect with them.

          The support worker you are assisting:
          - Name: #{profile.first_name} #{profile.last_name}
          - Location: #{sw_location}
          - Specialisations: #{sw_specialisations}

          When finding clients, you MUST apply these two checks:

          1. DISTANCE CHECK — You are based in #{sw_location}.
             Use your geographic knowledge to assess distance.
             If a client is more than ~100km away, flag this clearly and deprioritise them.
             Only surface local or nearby clients unless the worker explicitly asks otherwise.

          2. NEEDS FIT — Your specialisations are: #{sw_specialisations}.
             Only recommend clients whose health conditions or care needs align with what you do.
             If a client's needs fall outside your specialisations, say so directly.

          Workflow:
          1. Ask what kind of client or care need they are looking for
          2. Call get_clients to find candidates
          3. Apply distance and needs-fit checks — only present suitable clients
          4. Once they choose a client, call open_conversation
          5. Let them know they can message and send an invitation from the chat

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
            description: 'Fetch available support workers, including name, bio, experience, specialisations, availability and location.',
            input_schema: {
              type: 'object',
              properties: {
                keyword: { type: 'string', description: 'Optional keyword to filter by (searches bio, experience and specialisations)' }
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
      Rails.logger.debug "AI tool call: #{tool_use['name']} input=#{tool_use['input'].inspect}"
      result = case tool_use['name']
               when 'get_support_workers' then run_get_support_workers(tool_use['input']['keyword'])
               when 'get_clients'         then run_get_clients(tool_use['input']['keyword'])
               when 'open_conversation'   then run_open_conversation(tool_use['input']['person_id'], profile, is_client)
               else { error: "Unknown tool: #{tool_use['name']}" }
               end

      { type: 'tool_result', tool_use_id: tool_use['id'], content: result.to_json }
    end

    def run_get_support_workers(keyword)
      workers = SupportWorker.includes(:specialisations).where(status: 'approved')
      if keyword.present?
        kw = keyword.downcase
        workers = workers.select do |w|
          ["#{w.first_name} #{w.last_name}", w.location, w.bio, w.experience.to_s, w.specialisations.map(&:name).join(' ')].any? { |f| f.to_s.downcase.include?(kw) }
        end
      end
      workers.map do |w|
        { id: w.id, name: "#{w.first_name} #{w.last_name}", location: w.location,
          specialisations: w.specialisations.map(&:name), bio: w.bio,
          experience: w.experience, availability: w.availability }
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
