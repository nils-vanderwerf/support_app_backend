require 'rails_helper'

RSpec.describe SupportWorker, type: :model do
  let(:user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }

  def valid_worker(attrs = {})
    SupportWorker.new({
      user: user,
      first_name: 'Bob',
      last_name: 'Brown',
      email: 'sw@test.com',
      phone: '0400000000',
      age: 30,
      location: 'Sydney'
    }.merge(attrs))
  end

  describe 'validations' do
    it 'is valid with all required fields' do
      expect(valid_worker).to be_valid
    end

    %i[first_name last_name phone age location].each do |field|
      it "is invalid without #{field}" do
        worker = valid_worker(field => nil)
        expect(worker).not_to be_valid
        expect(worker.errors[field]).to include("can't be blank")
      end
    end

    it 'is invalid without an email' do
      worker = valid_worker(email: nil)
      expect(worker).not_to be_valid
      expect(worker.errors[:email]).to include("can't be blank")
    end

    it 'is invalid with a malformed email' do
      worker = valid_worker(email: 'not-an-email')
      expect(worker).not_to be_valid
      expect(worker.errors[:email]).to be_present
    end

    it 'is valid with a properly formatted email' do
      worker = valid_worker(email: 'bob.brown@example.com')
      expect(worker).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      expect(SupportWorker.reflect_on_association(:user).macro).to eq(:belongs_to)
    end

    it 'has many appointments' do
      expect(SupportWorker.reflect_on_association(:appointments).macro).to eq(:has_many)
    end

    it 'has and belongs to many specializations' do
      expect(SupportWorker.reflect_on_association(:specializations).macro).to eq(:has_and_belongs_to_many)
    end
  end
end
