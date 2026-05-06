require 'rails_helper'

RSpec.describe AppointmentReminderJob, type: :job do
  let(:client_user) { User.create!(email: 'client@test.com', first_name: 'Jane', last_name: 'Doe', password: 'password123') }
  let(:client) { Client.create!(user_id: client_user.id, first_name: 'Jane', last_name: 'Doe', email: 'client@test.com') }
  let(:support_worker_user) { User.create!(email: 'worker@test.com', first_name: 'Bob', last_name: 'Brown', password: 'password123', role: 'support_worker') }
  let(:support_worker) { SupportWorker.create!(user_id: support_worker_user.id, email: 'worker@test.com', first_name: 'Bob', last_name: 'Brown', phone: '0400000000', age: 30, location: 'Sydney') }
  let(:appointment) do
    Appointment.create!(
      client: client,
      support_worker: support_worker,
      date: 2.days.from_now,
      duration: 60,
      location: 'Sydney CBD'
    )
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
        expect(recipients).to include(client_user.email)
      end

      it 'sends an email to the support worker address' do
        described_class.perform_now(appointment.id)
        recipients = ActionMailer::Base.deliveries.map(&:to).flatten
        expect(recipients).to include('worker@test.com')
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
