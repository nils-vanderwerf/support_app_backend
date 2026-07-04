require 'rails_helper'

RSpec.describe Appointment, type: :model do
  describe 'validations' do
    it 'is valid with a date, client and support worker' do
      expect(build(:appointment)).to be_valid
    end

    it 'is invalid without a date' do
      appointment = build(:appointment, date: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:date]).to include("can't be blank")
    end

    it 'is invalid without a client' do
      appointment = build(:appointment, client: nil)
      expect(appointment).not_to be_valid
    end

    it 'is invalid without a support worker' do
      appointment = build(:appointment, support_worker: nil)
      expect(appointment).not_to be_valid
    end
  end

  describe 'overlap validation' do
    let(:worker) { create(:support_worker) }
    let(:client) { create(:client) }

    it 'is invalid when the support worker has an overlapping appointment' do
      create(:appointment, client: client, support_worker: worker, date: '2026-05-01 10:00', duration: 60)
      overlapping = build(:appointment, client: client, support_worker: worker, date: '2026-05-01 10:30', duration: 60)
      expect(overlapping).not_to be_valid
      expect(overlapping.errors[:date]).to include('conflicts with an existing appointment for this support worker')
    end

    it 'is valid when the support worker has a non-overlapping appointment' do
      create(:appointment, client: client, support_worker: worker, date: '2026-05-01 10:00', duration: 60)
      non_overlapping = build(:appointment, client: client, support_worker: worker, date: '2026-05-01 11:00', duration: 60)
      expect(non_overlapping).to be_valid
    end

    it 'allows a client to have overlapping appointments with different workers' do
      other_worker = create(:support_worker)
      create(:appointment, client: client, support_worker: worker, date: '2026-05-01 10:00', duration: 60)
      overlapping = build(:appointment, client: client, support_worker: other_worker, date: '2026-05-01 10:30', duration: 60)
      expect(overlapping).to be_valid
    end
  end

  describe '#save when the DB exclusion constraint fires' do
    it 'returns false and surfaces a date conflict error rather than raising' do
      appointment = build(:appointment)
      allow(appointment).to receive(:valid?).and_return(true)
      allow(appointment).to receive(:create_or_update).and_raise(
        ActiveRecord::StatementInvalid.new('PG::ExclusionViolation: no_overlapping_appointments')
      )

      result = appointment.save
      expect(result).to be false
      expect(appointment.errors[:date]).to include('conflicts with an existing appointment for this support worker')
    end

    it 're-raises StatementInvalid errors unrelated to the overlap constraint' do
      appointment = build(:appointment)
      allow(appointment).to receive(:valid?).and_return(true)
      allow(appointment).to receive(:create_or_update).and_raise(
        ActiveRecord::StatementInvalid.new('PG::NotNullViolation: something else')
      )

      expect { appointment.save }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe 'associations' do
    it 'belongs to a client' do
      expect(Appointment.reflect_on_association(:client).macro).to eq(:belongs_to)
    end

    it 'belongs to a support worker' do
      expect(Appointment.reflect_on_association(:support_worker).macro).to eq(:belongs_to)
    end
  end

  describe '.active' do
    it 'returns appointments where deleted_at is nil' do
      active = create(:appointment)
      expect(Appointment.active).to include(active)
    end

    it 'excludes soft-deleted appointments' do
      deleted = create(:appointment, :soft_deleted)
      expect(Appointment.active).not_to include(deleted)
    end
  end
end
