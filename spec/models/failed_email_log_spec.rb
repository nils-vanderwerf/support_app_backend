require 'rails_helper'

RSpec.describe FailedEmailLog, type: :model do
  describe 'creation' do
    it 'can be created with required fields' do
      log = FailedEmailLog.create!(
        job_class:     'AppointmentReminderJob',
        arguments:     '[123]',
        error_message: 'SMTP connection refused',
        failed_at:     Time.current
      )
      expect(log).to be_persisted
    end
  end

  describe '.unresolved' do
    it 'returns logs where resolved_at is nil' do
      unresolved = FailedEmailLog.create!(job_class: 'JobA', arguments: '[]', error_message: 'err', failed_at: Time.current)
      resolved   = FailedEmailLog.create!(job_class: 'JobB', arguments: '[]', error_message: 'err', failed_at: Time.current, resolved_at: Time.current)

      expect(FailedEmailLog.unresolved).to include(unresolved)
      expect(FailedEmailLog.unresolved).not_to include(resolved)
    end
  end

  describe '#resolve!' do
    it 'sets resolved_at to the current time' do
      log = FailedEmailLog.create!(job_class: 'JobA', arguments: '[]', error_message: 'err', failed_at: Time.current)
      expect(log.resolved_at).to be_nil

      log.resolve!

      expect(log.resolved_at).to be_present
    end

    it 'persists the resolved_at timestamp' do
      log = FailedEmailLog.create!(job_class: 'JobA', arguments: '[]', error_message: 'err', failed_at: Time.current)
      log.resolve!

      expect(log.reload.resolved_at).to be_present
    end
  end
end
