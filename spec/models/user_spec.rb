require 'rails_helper'

RSpec.describe User, type: :model do
  def valid_user(attrs = {})
    User.new({ email: 'user@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe' }.merge(attrs))
  end

  describe 'validations' do
    it 'is valid with an email and password' do
      expect(valid_user).to be_valid
    end

    it 'is invalid without an email' do
      user = valid_user(email: nil)
      expect(user).not_to be_valid
    end

    it 'is invalid without a password on create' do
      user = valid_user(password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'is invalid with a duplicate email' do
      User.create!(email: 'user@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe')
      user = valid_user
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end
  end

  describe 'role enum' do
    it 'defaults to no role' do
      user = User.create!(email: 'user@test.com', password: 'password123', first_name: 'Jane', last_name: 'Doe')
      expect(user.role).to be_nil
    end

    it 'can be set to client' do
      user = valid_user(role: :client)
      expect(user).to be_client
    end

    it 'can be set to support_worker' do
      user = valid_user(role: :support_worker)
      expect(user).to be_support_worker
    end

    it 'can be set to both' do
      user = valid_user(role: :both)
      expect(user).to be_both
    end
  end

  describe 'associations' do
    it 'has one client' do
      expect(User.reflect_on_association(:client).macro).to eq(:has_one)
    end

    it 'has one support worker' do
      expect(User.reflect_on_association(:support_worker).macro).to eq(:has_one)
    end
  end
end
