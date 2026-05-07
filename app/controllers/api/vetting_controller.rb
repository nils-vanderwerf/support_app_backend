module Api
  class VettingController < ApplicationController
    def chat
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
      worker = current_user.support_worker
      return render json: { error: 'Forbidden' }, status: :forbidden unless worker

      if worker.rejected_at.present? && worker.rejected_at > 3.days.ago
        reapply_at = worker.rejected_at + 3.days
        return render json: { error: 'waiting_period', reapply_at: reapply_at.iso8601 }, status: :forbidden
      end

      user_message = params[:message].to_s.strip
      history = params[:history] || []

      system_prompt = build_vetting_prompt(worker)

      messages = history.map { |m| { role: m['role'], content: m['content'] } }
      messages = messages.drop_while { |m| m[:role] == 'assistant' }
      messages << { role: 'user', content: user_message } if user_message.present?

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 400,
        system: system_prompt,
        messages: messages,
      })

      reply_text = response['content'].first['text'].strip

      extracted = nil
      if reply_text.include?('[VETTING_COMPLETE]')
        extracted = extract_vetting_data(history + [{ 'role' => 'user', 'content' => user_message }, { 'role' => 'assistant', 'content' => reply_text }])
        if extracted
          worker.update!(
            police_check_number: extracted[:police_check_number],
            police_check_expiry: extracted[:police_check_expiry],
            wwcc_number: extracted[:wwcc_number],
            wwcc_expiry: extracted[:wwcc_expiry],
            check_notes: extracted[:notes],
            agent_recommendation: extracted[:recommendation],
            status: 'pending'
          )
          VettingMailer.application_received(worker).deliver_later
        end
        reply_clean = reply_text.gsub('[VETTING_COMPLETE]', '').strip
      else
        reply_clean = reply_text
      end

      render json: {
        reply: reply_clean,
        complete: extracted.present?,
        recommendation: extracted&.dig(:recommendation),
      }
    rescue => e
      Rails.logger.error "VettingController error: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: e.message }, status: :internal_server_error
    end

    def status
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
      worker = current_user.support_worker
      return render json: { error: 'Forbidden' }, status: :forbidden unless worker

      if worker.rejected_at.present? && worker.rejected_at > 3.days.ago
        reapply_at = worker.rejected_at + 3.days
        return render json: { waiting_period: true, reapply_at: reapply_at.iso8601 }
      end

      render json: { waiting_period: false }
    end

    private

    def build_vetting_prompt(worker)
      <<~PROMPT
        You are a vetting assistant for a support worker platform. You are speaking with #{worker.first_name} #{worker.last_name}, who has just signed up as a support worker.

        Your job is to collect their compliance check details in this order:
        1. Police Check Number (a reference number from their police background check)
        2. Police Check expiry date
        3. Working With Children Check (WWCC) number
        4. WWCC expiry date

        IMPORTANT: The conversation has already started and you have already asked for the Police Check number. Do NOT re-introduce yourself or re-explain the process. Simply continue the conversation naturally from where it left off.

        Be friendly and professional. Ask for one piece of information at a time. If they provide a number or date, confirm it back to them before moving on.

        For expiry dates: accept any natural date format (e.g. "March 2027", "03/2027", "15/03/2027"). If the date is in the past or unclear, ask them to clarify. Expiry dates must be in the future.

        Once you have ALL FOUR pieces of information:
        - Simulate a verification check (always pass for demonstration purposes)
        - Give a recommendation: "approved" or "needs_review"
        - End your final message with [VETTING_COMPLETE] on its own line

        A plausible reference number must meet ALL of these criteria:
        - At least 6 characters long
        - Contains at least one digit (0-9)
        - Is not a plain dictionary word or name

        If a number does not meet these criteria, tell the worker it doesn't look like a valid reference number and ask them to double-check and provide the correct one. Do not accept it.

        Your recommendation should be "approved" if both numbers are plausible and both expiry dates are in the future, otherwise "needs_review".

        Keep replies concise (1-3 sentences).
      PROMPT
    end

    def extract_vetting_data(full_history)
      transcript = full_history.map { |m| "[#{m['role']}]: #{m['content']}" }.join("\n")

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 200,
        system: "Extract vetting data from this conversation. Return ONLY valid JSON: {\"police_check_number\": \"...\", \"police_check_expiry\": \"YYYY-MM-DD\", \"wwcc_number\": \"...\", \"wwcc_expiry\": \"YYYY-MM-DD\", \"recommendation\": \"approved|needs_review\", \"notes\": \"brief summary\"}. Normalise expiry dates to YYYY-MM-DD. Use null for missing values. Today is #{Date.today}.",
        messages: [{ role: 'user', content: transcript }],
      })

      text = response['content'].first['text'].strip.gsub(/\A```(?:json)?\n?/, '').gsub(/\n?```\z/, '').strip
      data = JSON.parse(text)
      data.transform_keys(&:to_sym)
    rescue
      nil
    end
  end
end
