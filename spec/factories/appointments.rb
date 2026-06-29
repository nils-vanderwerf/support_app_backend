FactoryBot.define do
  factory :appointment do
    association :client
    association :support_worker
    date { 1.week.from_now }
    duration { 60 }
    location { 'Sydney Community Centre' }
    status { 'approved' }

    trait :pending do
      status { 'pending' }
    end

    trait :past do
      date { 1.week.ago }
    end

    trait :soft_deleted do
      deleted_at { 1.day.ago }
    end

    trait :with_conversation do
      association :conversation
    end
  end
end
