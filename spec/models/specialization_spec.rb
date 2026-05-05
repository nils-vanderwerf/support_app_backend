require 'rails_helper'

RSpec.describe Specialization, type: :model do
  it 'can be created with a name' do
    specialization = Specialization.create!(name: 'Personal Care')
    expect(specialization.name).to eq('Personal Care')
  end

  it 'persists to the database' do
    expect { Specialization.create!(name: 'Meal Preparation') }.to change(Specialization, :count).by(1)
  end
end
