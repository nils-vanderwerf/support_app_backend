require 'rails_helper'

RSpec.describe VisitReport, type: :model do
  describe 'creation' do
    it 'can be created with all fields' do
      report = create(:visit_report)
      expect(report).to be_persisted
      expect(report.activities).to be_present
    end
  end

  describe 'validations' do
    it 'enforces appointment uniqueness' do
      existing = create(:visit_report)
      duplicate = build(:visit_report, appointment: existing.appointment)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:appointment_id]).to be_present
    end
  end

  describe 'associations' do
    it 'belongs to an appointment' do
      expect(VisitReport.reflect_on_association(:appointment).macro).to eq(:belongs_to)
    end
  end
end
