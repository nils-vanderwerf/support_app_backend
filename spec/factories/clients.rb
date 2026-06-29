FactoryBot.define do
  factory :client do
    association :user
    first_name { 'Jane' }
    last_name { 'Doe' }
    location { 'Sydney' }
    phone { '0400000000' }
    sequence(:email) { |n| "client#{n}@example.com" }
    date_of_birth { 35.years.ago.to_date }
    health_conditions { 'Mobility difficulties' }
    bio { 'Looking for compassionate support with daily living.' }
  end
end
