module Api
  class VettingController < ApplicationController
    def chat
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
      worker = current_user.support_worker
      return render json: { error: 'Forbidden' }, status: :forbidden unless worker

      user_message = params[:message].to_s.strip
      history = params[:history] || []

      system_prompt = build_vetting_prompt(worker)

      messages = history.map { |m| { role: m['role'], content: m['content'] } }
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
            wwcc_number: extracted[:wwcc_number],
            check_notes: extracted[:notes],
            agent_recommendation: extracted[:recommendation]
          )
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
    end

    private

    def build_vetting_prompt(worker)
      <<~PROMPT
        You are a vetting assistant for a support worker platform. You are speaking with #{worker.first_name} #{worker.last_name}, who has just signed up as a support worker.

        Your job is to collect their compliance check details:
        1. Police Check Number (a reference number from their police background check)
        2. Working With Children Check (WWCC) number

        IMPORTANT: The conversation has already started and you have already asked for the Police Check number. Do NOT re-introduce yourself or re-explain the process. Simply continue the conversation naturally from where it left off.

        Be friendly and professional. Ask for one piece of information at a time. If they provide a number, confirm it back to them before moving on.

        Once you have BOTH numbers:
        - Simulate a verification check (always pass for demonstration purposes)
        - Give a recommendation: "approved" or "needs_review"
        - End your final message with [VETTING_COMPLETE] on its own line

        A plausible reference number must meet ALL of these criteria:
        - At least 6 characters long
        - Contains at least one digit (0-9)
        - Is not a plain dictionary word or name

        If a number does not meet these criteria, tell the worker it doesn't look like a valid reference number and ask them to double-check and provide the correct one. Do not accept it.

        Your recommendation should be "approved" if both numbers are plausible reference numbers, otherwise "needs_review".

        Keep replies concise (1-3 sentences).
      PROMPT
    end

    def extract_vetting_data(full_history)
      transcript = full_history.map { |m| "[#{m['role']}]: #{m['content']}" }.join("\n")

      anthropic = Anthropic::Client.new(access_token: ENV['ANTHROPIC_API_KEY'])
      response = anthropic.messages(parameters: {
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 200,
        system: 'Extract vetting data from this conversation. Return ONLY valid JSON: {"police_check_number": "...", "wwcc_number": "...", "recommendation": "approved|needs_review", "notes": "brief summary"}. Use null for missing values.',
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
