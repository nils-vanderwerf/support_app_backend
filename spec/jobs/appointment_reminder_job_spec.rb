require 'rails_helper'

RSpec.describe AppointmentReminderJob, type: :job do
  let(:client)         { create(:client) }
  let(:support_worker) { create(:support_worker) }
  let(:appointment) do
    create(:appointment, client: client, support_worker: support_worker,
           date: 2.days.from_now, duration: 60, location: 'Sydney CBD')
  end

  describe '#perform' do
    context 'when the appointment exists and is not deleted' do
      it 'sends a reminder to the client' do
        expect { described_class.perform_now(appointment.id) }
          .to change { ActionMailer::Base.deliveries.count }.by(2)
      end

      it 'sends an email to the client address' do
        described_class.perform_now(appointment.id)
        recipients = ActionMailer::Base.deliveries.map(&:to).flatten
        expect(recipients).to include(client.email)
      end

      it 'sends an email to the support worker address' do
        described_class.perform_now(appointment.id)
        recipients = ActionMailer::Base.deliveries.map(&:to).flatten
        expect(recipients).to include(support_worker.email)
      end
    end

    context 'when the appointment has been soft-deleted' do
      before { appointment.update!(deleted_at: Time.current) }

      it 'does not send any emails' do
        expect { described_class.perform_now(appointment.id) }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when the appointment does not exist' do
      it 'does not raise an error' do
        expect { described_class.perform_now(99999) }.not_to raise_error
      end

      it 'does not send any emails' do
        expect { described_class.perform_now(99999) }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
