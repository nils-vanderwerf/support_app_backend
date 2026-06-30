FactoryBot.define do
  factory :review do
    association :client
    association :support_worker
    association :appointment, factory: %i[appointment past]
    rating { 5 }
    comment { 'Great support worker!' }

    before(:create) do |review, evaluator|
      appt = review.appointment
      appt.update_columns(
        client_id: review.client.id,
        support_worker_id: review.support_worker.id,
        status: 'approved'
      )
    end
  end
end
