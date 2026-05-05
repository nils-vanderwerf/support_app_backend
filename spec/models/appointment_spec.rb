require 'rails_helper'

RSpec.describe Appointment, type: :model do
  let(:client_user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }
  let(:client) { Client.create!(user: client_user, first_name: 'Jane', last_name: 'Doe') }
  let(:sw_user) { User.create!(email: 'sw@test.com', password: 'password123', first_name: 'Bob', last_name: 'Brown') }
  let(:support_worker) { SupportWorker.create!(user: sw_user, first_name: 'Bob', last_name: 'Brown', email: 'sw@test.com', phone: '0400000000', age: 30, location: 'Sydney') }

  def valid_appointment(attrs = {})
    Appointment.new({ client: client, support_worker: support_worker, date: '2026-05-01' }.merge(attrs))
  end

  describe 'validations' do
    it 'is valid with a date, client and support worker' do
      expect(valid_appointment).to be_valid
    end

    it 'is invalid without a date' do
      appointment = valid_appointment(date: nil)
      expect(appointment).not_to be_valid
      expect(appointment.errors[:date]).to include("can't be blank")
    end

    it 'is invalid without a client' do
      appointment = valid_appointment(client: nil)
      expect(appointment).not_to be_valid
    end

    it 'is invalid without a support worker' do
      appointment = valid_appointment(support_worker: nil)
      expect(appointment).not_to be_valid
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
      active = Appointment.create!(client: client, support_worker: support_worker, date: '2026-05-01', deleted_at: nil)
      expect(Appointment.active).to include(active)
    end

    it 'excludes soft-deleted appointments' do
      deleted = Appointment.create!(client: client, support_worker: support_worker, date: '2026-05-02', deleted_at: Time.current)
      expect(Appointment.active).not_to include(deleted)
    end
  end
end
