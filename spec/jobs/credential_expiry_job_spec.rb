require 'rails_helper'

RSpec.describe CredentialExpiryJob, type: :job do
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Alice', last_name: 'Smith', role: 'support_worker') }
  let(:worker) { SupportWorker.create!(user: sw_user, first_name: 'Alice', last_name: 'Smith', email: 'sw@test.com', phone: '0400000000', location: 'Sydney', status: 'approved') }

  describe '#perform' do
    context 'when a worker has a WWCC expiring in exactly 30 days' do
      before { worker.update!(wwcc_expiry: Date.today + 30) }

      it 'sends a warning email to the worker' do
        expect(CredentialExpiryMailer).to receive(:worker_warning)
          .with(worker, 'WWCC', Date.today + 30, 30)
          .and_return(double(deliver_now: true))
        expect(CredentialExpiryMailer).to receive(:admin_digest).and_return(double(deliver_now: true))
        described_class.perform_now
      end
    end

    context 'when a worker has a Police Check expiring in exactly 7 days' do
      before { worker.update!(police_check_expiry: Date.today + 7) }

      it 'sends a warning email to the worker' do
        expect(CredentialExpiryMailer).to receive(:worker_warning)
          .with(worker, 'Police Check', Date.today + 7, 7)
          .and_return(double(deliver_now: true))
        expect(CredentialExpiryMailer).to receive(:admin_digest).and_return(double(deliver_now: true))
        described_class.perform_now
      end
    end

    context 'when a worker has credentials expiring in a non-milestone number of days' do
      before { worker.update!(wwcc_expiry: Date.today + 20, police_check_expiry: Date.today + 45) }

      it 'sends no emails' do
        expect(CredentialExpiryMailer).not_to receive(:worker_warning)
        expect(CredentialExpiryMailer).not_to receive(:admin_digest)
        described_class.perform_now
      end
    end

    context 'when no workers have credentials at a milestone' do
      it 'does not send an admin digest' do
        worker
        expect(CredentialExpiryMailer).not_to receive(:admin_digest)
        described_class.perform_now
      end
    end

    context 'when a worker is pending (not approved)' do
      before do
        worker.update!(status: 'pending', wwcc_expiry: Date.today + 30)
      end

      it 'skips the pending worker' do
        expect(CredentialExpiryMailer).not_to receive(:worker_warning)
        described_class.perform_now
      end
    end
  end
end
