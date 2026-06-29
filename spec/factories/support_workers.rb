FactoryBot.define do
  factory :support_worker do
    association :user, factory: [:user, :as_support_worker]
    first_name { 'Olivia' }
    last_name { 'Williams' }
    sequence(:email) { |n| "worker#{n}@example.com" }
    phone { '0400000000' }
    location { 'Sydney' }
    status { 'approved' }
    bio { 'Experienced disability support worker with 5 years in aged care.' }
    experience { 5 }

    trait :pending do
      status { 'pending' }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :with_credentials do
      police_check_number { 'PC123456' }
      police_check_expiry { 2.years.from_now.to_date }
      wwcc_number { 'WWC1234567E' }
      wwcc_expiry { 2.years.from_now.to_date }
      state { 'nsw' }
    end

    trait :with_specialisations do
      after(:create) do |worker|
        worker.specialisations << create(:specialisation, name: 'Aged Care')
        worker.specialisations << create(:specialisation, name: 'Mental Health')
      end
    end
  end
end
