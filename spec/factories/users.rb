FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    first_name { 'Jane' }
    last_name { 'Doe' }
    role { :client }

    trait :as_support_worker do
      role { :support_worker }
      first_name { 'Bob' }
      last_name { 'Brown' }
    end

    trait :as_admin do
      role { :admin }
      first_name { 'Admin' }
      last_name { 'User' }
    end
  end
end
