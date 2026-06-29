require 'rails_helper'

RSpec.describe SupportWorker, type: :model do
  describe 'validations' do
    it 'is valid with all required fields' do
      expect(build(:support_worker)).to be_valid
    end

    %i[first_name last_name phone location].each do |field|
      it "is invalid without #{field}" do
        worker = build(:support_worker, field => nil)
        expect(worker).not_to be_valid
        expect(worker.errors[field]).to include("can't be blank")
      end
    end

    it 'is invalid without an email' do
      worker = build(:support_worker, email: nil)
      expect(worker).not_to be_valid
      expect(worker.errors[:email]).to include("can't be blank")
    end

    it 'is invalid with a malformed email' do
      worker = build(:support_worker, email: 'not-an-email')
      expect(worker).not_to be_valid
      expect(worker.errors[:email]).to be_present
    end

    it 'is valid with a properly formatted email' do
      expect(build(:support_worker, email: 'bob.brown@example.com')).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      expect(SupportWorker.reflect_on_association(:user).macro).to eq(:belongs_to)
    end

    it 'has many appointments' do
      expect(SupportWorker.reflect_on_association(:appointments).macro).to eq(:has_many)
    end

    it 'has and belongs to many specialisations' do
      expect(SupportWorker.reflect_on_association(:specialisations).macro).to eq(:has_and_belongs_to_many)
    end
  end

  describe 'scopes' do
    it '.approved returns only approved workers' do
      approved = create(:support_worker, :pending)
      approved.update!(status: 'approved')
      pending  = create(:support_worker, :pending)
      expect(SupportWorker.approved).to include(approved)
      expect(SupportWorker.approved).not_to include(pending)
    end
  end
end
