require 'rails_helper'

RSpec.describe Client, type: :model do
  let(:user) { User.create!(email: 'client@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe') }

  def valid_client(attrs = {})
    Client.new({ user: user, first_name: 'Jane', last_name: 'Doe' }.merge(attrs))
  end

  describe 'validations' do
    it 'is valid with a first name, last name and user' do
      expect(valid_client).to be_valid
    end

    it 'is invalid without a first name' do
      client = valid_client(first_name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:first_name]).to include("can't be blank")
    end

    it 'is invalid without a last name' do
      client = valid_client(last_name: nil)
      expect(client).not_to be_valid
      expect(client.errors[:last_name]).to include("can't be blank")
    end

    it 'is invalid without a user' do
      client = valid_client(user: nil)
      expect(client).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      expect(Client.reflect_on_association(:user).macro).to eq(:belongs_to)
    end

    it 'has many appointments' do
      expect(Client.reflect_on_association(:appointments).macro).to eq(:has_many)
    end
  end
end
