FactoryBot.define do
  factory :conversation do
    association :client
    association :support_worker
  end
end
