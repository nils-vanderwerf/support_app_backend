FactoryBot.define do
  factory :specialisation do
    sequence(:name) { |n| "Specialisation #{n}" }
  end
end
