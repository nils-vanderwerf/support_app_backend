require 'rails_helper'

RSpec.describe Specialisation, type: :model do
  it 'can be created with a name' do
    specialisation = Specialisation.create!(name: 'Personal Care')
    expect(specialisation.name).to eq('Personal Care')
  end

  it 'persists to the database' do
    expect { Specialisation.create!(name: 'Meal Preparation') }.to change(Specialisation, :count).by(1)
  end
end
