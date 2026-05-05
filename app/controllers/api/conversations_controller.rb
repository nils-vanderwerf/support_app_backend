module Api
  class ConversationsController < ApplicationController
    def index
      with_messages = Message.select(:conversation_id)
      conversations = if current_user.client
        Conversation.where(client_id: current_user.client.id)
                    .where(id: with_messages)
                    .includes(:support_worker, :messages)
      elsif current_user.support_worker
        Conversation.where(support_worker_id: current_user.support_worker.id)
                    .where(id: with_messages)
                    .includes(:client, :messages)
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
          appointments: { only: %i[id date duration location notes status initiated_by] },
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
        "[#{m.sender_type}]: #{decrypt_content(m.content, conversation.id)}"
      end.join("\n")

      return render json: {} if transcript.blank?

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 200,
        system: "Extract appointment booking details from this conversation transcript. Return ONLY valid JSON with these exact keys (use null for anything not mentioned): {\"date\": \"YYYY-MM-DD\", \"time\": \"HH:MM\", \"duration\": <minutes as integer or null>, \"location\": \"string or null\", \"notes\": \"string or null\"}. Today is #{Date.today} (#{Date.today.strftime('%A')}). Resolve relative days like 'next Tuesday' or 'tomorrow' to the next upcoming occurrence of that weekday as an absolute YYYY-MM-DD date. After resolving, verify the weekday of your chosen date matches what was mentioned (e.g. if 'Thursday' was mentioned, confirm your date is actually a Thursday). Do not wrap in markdown.",
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

      pending_appts = conversation.appointments.select { |a| a.status == 'pending' }
      pending_appt  = pending_appts.first

      history = conversation.messages.order(:created_at).map do |m|
        role = m.sender_type == simulated_role ? 'assistant' : 'user'
        { role: role, content: decrypt_content(m.content, conversation.id) }
      end

      # If no messages yet, prime the AI to open the conversation
      if history.empty?
        history = [{ role: 'user', content: 'Please introduce yourself and start our conversation.' }]
      elsif history.last[:role] == 'assistant'
        # In a continuation flow the last saved message is from the AI — add a silent nudge so the API call is valid
        history << { role: 'user', content: '[continue]' }
      end

      # In a continuation flow the last saved message is from the AI — add a silent nudge so the API call is valid
      history << { role: 'user', content: '[continue]' } if history.last[:role] == 'assistant'

      persona = build_persona(simulated_person, simulated_role, current_person, pending_appts)

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
        content: encrypt_content(reply_clean, conversation.id),
        sender_type: simulated_role,
        sender_id: simulated_person.id
      )

      # Handle approve/decline action
      affected_appt = pending_appt
      declined_all  = false
      if pending_appt && action == 'approve'
        pending_appt.update!(status: 'approved')
        schedule_reminder(pending_appt)
      elsif pending_appt && action == 'decline'
        pending_appt.update!(status: 'declined')
      elsif pending_appts.any? && action == 'decline_all'
        pending_appts.each { |a| a.update!(status: 'declined') }
        declined_all = true
      elsif action == 'send_invitation' && parsed_action
        affected_appt = conversation.appointments.create!(
          date:             parsed_action['date'],
          duration:         parsed_action['duration'],
          location:         parsed_action['location'],
          notes:            parsed_action['notes'],
          client_id:        conversation.client_id,
          support_worker_id: conversation.support_worker_id,
          status:           'pending',
          conversation_id:  conversation.id,
          initiated_by:     simulated_role
        )
        appt_time = Time.parse(affected_appt.date.to_s).strftime('%-d %B at %-I:%M %p') rescue affected_appt.date.to_s
        conversation.messages.create!(
          content: encrypt_content("[SYS]✓ Appointment invitation sent for #{appt_time}.", conversation.id),
          sender_type: simulated_role,
          sender_id: simulated_person.id
        )
      elsif action == 'send_recurring_invitations' && parsed_action
        dates = Array(parsed_action['dates'])
        created_appts = dates.map do |date|
          appt = conversation.appointments.create!(
            date:             date,
            duration:         parsed_action['duration'],
            location:         parsed_action['location'],
            notes:            parsed_action['notes'],
            client_id:        conversation.client_id,
            support_worker_id: conversation.support_worker_id,
            status:           'pending',
            conversation_id:  conversation.id,
            initiated_by:     simulated_role
          )
          appt_time = Time.parse(appt.date.to_s).strftime('%-d %B at %-I:%M %p') rescue appt.date.to_s
          conversation.messages.create!(
            content: encrypt_content("[SYS]✓ Appointment invitation sent for #{appt_time}.", conversation.id),
            sender_type: simulated_role,
            sender_id: simulated_person.id
          )
          appt
        end
      end

      render json: {
        message: msg.as_json(only: %i[id content sender_type sender_id created_at]).merge('content' => reply_clean),
        action: action,
        appointment: affected_appt&.reload&.as_json(only: %i[id status date duration location notes initiated_by]),
        appointments: created_appts&.map { |a| a.reload.as_json(only: %i[id status date duration location notes initiated_by]) },
        declined_all: declined_all,
        continue: will_continue,
      }
    end

    private

    ENCRYPTION_CONTEXT = 'support-app-messages-v1'

    # Mirrors the frontend encryptMessage/decryptMessage in src/utils/encryption.ts.
    # Key derivation: HKDF-SHA256, IKM = salt = APP_CONTEXT, info = "conv-{id}".
    # Wire format: Base64( 12-byte IV | AES-256-GCM ciphertext+tag ), prefixed "ENC:".
    def decrypt_content(content, conversation_id)
      return content unless content.start_with?('ENC:')

      combined = Base64.decode64(content[4..])
      return content if combined.bytesize < 29 # 12 IV + 1 byte minimum + 16 tag

      iv              = combined[0, 12]
      encrypted_plus_tag = combined[12..]
      tag             = encrypted_plus_tag[-16..]
      ciphertext      = encrypted_plus_tag[0..-17]

      # HKDF-Extract: PRK = HMAC-SHA256(salt, IKM)
      prk = OpenSSL::HMAC.digest('SHA256', ENCRYPTION_CONTEXT, ENCRYPTION_CONTEXT)
      # HKDF-Expand: T(1) = HMAC-SHA256(PRK, info || 0x01), first 32 bytes
      key = OpenSSL::HMAC.digest('SHA256', prk, "conv-#{conversation_id}\x01")[0, 32]

      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.decrypt
      cipher.key      = key
      cipher.iv       = iv
      cipher.auth_tag = tag
      cipher.auth_data = ''

      cipher.update(ciphertext) + cipher.final
    rescue StandardError
      content
    end

    def encrypt_content(plaintext, conversation_id)
      prk = OpenSSL::HMAC.digest('SHA256', ENCRYPTION_CONTEXT, ENCRYPTION_CONTEXT)
      key = OpenSSL::HMAC.digest('SHA256', prk, "conv-#{conversation_id}\x01")[0, 32]

      iv = SecureRandom.random_bytes(12)

      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.encrypt
      cipher.key      = key
      cipher.iv       = iv
      cipher.auth_data = ''

      ciphertext = cipher.update(plaintext) + cipher.final
      tag = cipher.auth_tag  # 16 bytes, appended to match Web Crypto wire format

      'ENC:' + Base64.strict_encode64(iv + ciphertext + tag)
    end

    def build_persona(simulated_person, simulated_role, current_person, pending_appts)
      name = "#{simulated_person.first_name} #{simulated_person.last_name}"
      other_name = current_person.first_name

      today = Date.today.strftime('%A, %-d %B %Y')

      invitation_instructions = <<~INV
        Today is #{today}.
        When you and #{other_name} have clearly agreed on a date, time, location and duration for an appointment,
        proactively offer to send a formal invitation. Once confirmed, your ENTIRE response must be ONLY this JSON with no surrounding text whatsoever:
        For a single appointment: {"message": "your friendly confirmation message", "action": "send_invitation", "date": "YYYY-MM-DDTHH:MM:00+HH:MM", "duration": <minutes>, "location": "place"}
        For multiple recurring appointments (e.g. "3 more weekly sessions"): {"message": "your friendly confirmation message", "action": "send_recurring_invitations", "dates": ["YYYY-MM-DDTHH:MM:00+HH:MM", ...], "duration": <minutes>, "location": "place"}
        Use the actual agreed date(s), time and location. Include the correct UTC offset for Sydney time (+10:00).
        Do NOT write any text before or after the JSON object.
      INV

      booking_section = if pending_appts.any?
        ''
      elsif approved_appts.any?
        "Do NOT proactively suggest booking a new appointment. Only send an invitation if #{other_name} explicitly asks for one.\n#{invitation_instructions}"
      else
        invitation_instructions
      end

      base = if simulated_role == 'support_worker'
        <<~P
          You are #{name} (the SUPPORT WORKER). You are chatting with #{other_name}, who is your CLIENT.
          CRITICAL: You are #{name}. The other person is #{other_name}. Never call #{other_name} by your own name (#{simulated_person.first_name}).
          Your details — Location: #{simulated_person.location}, Bio: #{simulated_person.bio.presence || 'experienced support worker'}.
          Be warm, professional and concise. Keep replies to 1-3 sentences.
          If you intend to immediately follow up with more content, end your message with [CONTINUE] on its own line.
          #{booking_section}
        P
      else
        <<~P
          You are #{name} (the CLIENT). You are chatting with #{other_name}, who is your SUPPORT WORKER.
          CRITICAL: You are #{name}. The other person is #{other_name}. Never call #{other_name} by your own name (#{simulated_person.first_name}).
          Be natural and conversational. Keep replies to 1-3 sentences.
          If you intend to immediately follow up with more content, end your message with [CONTINUE] on its own line.
          #{booking_section}
        P
      end

      if pending_appts.any?
        appt_list = pending_appts.map do |a|
          label = Time.parse(a.date.to_s).strftime('%A, %b %-d at %-I:%M %p') rescue a.date.to_s
          "- #{label} (#{a.duration} min, #{a.location})"
        end.join("\n")

        base += <<~P

          There #{pending_appts.count == 1 ? 'is' : 'are'} #{pending_appts.count} pending appointment invitation(s):
          #{appt_list}

          If #{other_name} asks you to approve or decline any of these — or you decide to — include a JSON action at the end of your reply:
          - Approve the first pending invitation: {"message": "your reply", "action": "approve"}
          - Decline the first pending invitation: {"message": "your reply", "action": "decline"}
          - Decline ALL remaining invitations: {"message": "your reply", "action": "decline_all"}
          Only include the JSON when actually taking an action.
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
