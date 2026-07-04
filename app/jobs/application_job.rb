class ApplicationJob < ActiveJob::Base
  discard_on ActiveJob::DeserializationError

  # Retry transient network/SMTP failures up to 3 times with increasing waits
  # (roughly 3s, 18s, 83s). After the third failure the block runs and the job
  # is written to failed_email_logs for manual inspection and replay.
  retry_on Net::SMTPError,
           Net::OpenTimeout,
           Net::ReadTimeout,
           Errno::ECONNREFUSED,
           wait: :polynomially_longer,
           attempts: 3 do |job, error|
    FailedEmailLog.create!(
      job_class:     job.class.name,
      arguments:     job.arguments.to_json,
      error_message: error.message,
      failed_at:     Time.current
    )
    Rails.logger.error "[DLQ] #{job.class.name} failed permanently after 3 attempts: #{error.message}"
  end
end
