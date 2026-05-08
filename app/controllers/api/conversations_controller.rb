module Api
  class ConversationsController < ApplicationController
    def index
      conversations = if current_user.client
        Conversation.where(client_id: current_user.client.id).includes(:support_worker, :messages)
      elsif current_user.support_worker
        Conversation.where(support_worker_id: current_user.support_worker.id).includes(:client, :messages)
      else
        []
      end
      render json: conversations.as_json(
        include: {
          client: {},
          support_worker: {},
          messages: { only: %i[id content sender_type sender_id created_at] },
        }
      )
    end

    def show
      conversation = Conversation.includes(:client, :support_worker, :messages).find(params[:id])
      render json: conversation.as_json(
        include: {
          client: {},
          support_worker: {},
          messages: { only: %i[id content sender_type sender_id created_at] },
          appointments: { only: %i[id date duration location notes status] },
        }
      )
    end

    def create
      conversation = if current_user.client
        Conversation.find_or_create_by(
          client_id: current_user.client.id,
          support_worker_id: params[:support_worker_id]
        )
      elsif current_user.support_worker
        Conversation.find_or_create_by(
          client_id: params[:client_id],
          support_worker_id: current_user.support_worker.id
        )
      end
      render json: conversation, status: :created
    end

    def suggest_booking
      conversation = Conversation.includes(:messages).find(params[:id])

      transcript = conversation.messages.order(:created_at).last(12).map do |m|
        "[#{m.sender_type}]: #{m.content}"
      end.join("\n")

      return render json: {} if transcript.blank?

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 200,
        system: "Extract appointment booking details from this conversation transcript. Return ONLY valid JSON with these exact keys (use null for anything not mentioned): {\"date\": \"YYYY-MM-DD\", \"time\": \"HH:MM\", \"duration\": <minutes as integer or null>, \"location\": \"string or null\", \"notes\": \"string or null\"}. Today is #{Date.today} (#{Date.today.strftime('%A')}). Resolve relative days like 'next Tuesday' or 'tomorrow' to absolute YYYY-MM-DD dates. Do not wrap in markdown.",
        messages: [{ role: 'user', content: transcript }],
      })

      text = response['content'].first['text'].strip.gsub(/\A```(?:json)?\n?/, '').gsub(/\n?```\z/, '').strip

      begin
        render json: JSON.parse(text)
      rescue JSON::ParserError
        render json: {}
      end
    end

    def ai_respond
      conversation = Conversation.includes(:client, :support_worker, :messages, :appointments).find(params[:id])

      is_client = current_user.client.present?
      simulated_role = is_client ? 'support_worker' : 'client'
      simulated_person = is_client ? conversation.support_worker : conversation.client
      current_person  = is_client ? conversation.client : conversation.support_worker

      pending_appt = conversation.appointments.find { |a| a.status == 'pending' }

      history = conversation.messages.order(:created_at).map do |m|
        role = m.sender_type == simulated_role ? 'assistant' : 'user'
        { role: role, content: m.content }
      end

      return render json: { error: 'No message to respond to' }, status: :unprocessable_entity if history.empty?

      # In a continuation flow the last saved message is from the AI — add a silent nudge so the API call is valid
      history << { role: 'user', content: '[continue]' } if history.last[:role] == 'assistant'

      persona = build_persona(simulated_person, simulated_role, current_person, pending_appt)

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-sonnet-4-6',
        max_tokens: 400,
        system: persona,
        messages: history,
      })

      reply_text = response['content'].first['text'].strip

      # Parse optional JSON action from Claude — may be the full reply or embedded within prose
      action = nil
      parsed_action = nil
      reply_clean = reply_text
      if (start_idx = reply_text.index('{')) && (end_idx = reply_text.rindex('}'))
        begin
          candidate = reply_text[start_idx..end_idx]
          parsed = JSON.parse(candidate)
          if parsed.key?('action')
            parsed_action = parsed
            action = parsed['action']
            reply_clean = parsed['message'].presence || reply_text[0...start_idx].strip
          end
        rescue JSON::ParserError
        end
      end

      # Strip [CONTINUE] signal and flag it
      will_continue = reply_clean.include?('[CONTINUE]')
      reply_clean = reply_clean.gsub('[CONTINUE]', '').strip

      msg = conversation.messages.create!(
        content: reply_clean,
        sender_type: simulated_role,
        sender_id: simulated_person.id
      )

      # Handle approve/decline action
      affected_appt = pending_appt
      if pending_appt && action == 'approve'
        pending_appt.update!(status: 'approved')
        schedule_reminder(pending_appt)
      elsif pending_appt && action == 'decline'
        pending_appt.update!(status: 'declined')
      elsif action == 'send_invitation' && parsed_action
        affected_appt = conversation.appointments.create!(
          date:             parsed_action['date'],
          duration:         parsed_action['duration'],
          location:         parsed_action['location'],
          notes:            parsed_action['notes'],
          client_id:        conversation.client_id,
          support_worker_id: conversation.support_worker_id,
          status:           'pending',
          conversation_id:  conversation.id
        )
      end

      render json: {
        message: msg.as_json(only: %i[id content sender_type sender_id created_at]),
        action: action,
        appointment: affected_appt&.reload&.as_json(only: %i[id status date duration location notes]),
        continue: will_continue,
      }
    end

    private

    def build_persona(simulated_person, simulated_role, current_person, pending_appt)
      name = "#{simulated_person.first_name} #{simulated_person.last_name}"
      other_name = current_person.first_name

      today = Date.today.strftime('%A, %-d %B %Y')

      base = if simulated_role == 'support_worker'
        <<~P
          You are #{name} (the SUPPORT WORKER). You are chatting with #{other_name}, who is your CLIENT.
          CRITICAL: You are #{name}. The other person is #{other_name}. Never call #{other_name} by your own name (#{simulated_person.first_name}).
          Your details — Location: #{simulated_person.location}, Bio: #{simulated_person.bio.presence || 'experienced support worker'}.
          Be warm, professional and concise. Keep replies to 1-3 sentences.
          If you intend to immediately follow up with more content, end your message with [CONTINUE] on its own line.
        P
      else
        <<~P
          You are #{name} (the CLIENT). You are chatting with #{other_name}, who is your SUPPORT WORKER.
          CRITICAL: You are #{name}. The other person is #{other_name}. Never call #{other_name} by your own name (#{simulated_person.first_name}).
          Be natural and conversational. Keep replies to 1-3 sentences.
          If you intend to immediately follow up with more content, end your message with [CONTINUE] on its own line.
          Today is #{today}.
          When you and #{other_name} have clearly agreed on a date, time, location and duration for an appointment,
          proactively offer to send a formal invitation. Once confirmed, your ENTIRE response must be ONLY this JSON with no surrounding text whatsoever:
          {"message": "your friendly confirmation message", "action": "send_invitation", "date": "YYYY-MM-DDTHH:MM:00+HH:MM", "duration": <minutes>, "location": "place"}
          Use the actual agreed date, time and location. Include the correct UTC offset for Sydney time (+10:00).
          Do NOT write any text before or after the JSON object.
        P
      end

      if pending_appt
        appt_time = Time.parse(pending_appt.date.to_s).strftime('%A, %b %-d at %-I:%M %p') rescue pending_appt.date.to_s
        base += <<~P

          There is a pending appointment invitation for #{appt_time} (#{pending_appt.duration} min, #{pending_appt.location}).
          If it suits you, respond naturally and include a JSON decision at the end of your reply like this:
          {"message": "your reply here", "action": "approve"}
          Or to decline: {"message": "your reply here", "action": "decline"}
          Only include the JSON if you are making a decision about the appointment.
        P
      end

      base
    end

    def schedule_reminder(appointment)
      reminder_time = appointment.date - 24.hours
      return unless reminder_time > Time.current
      AppointmentReminderJob.set(wait_until: reminder_time).perform_later(appointment.id)
    end
  end
end
