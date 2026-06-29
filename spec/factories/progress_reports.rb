FactoryBot.define do
  factory :progress_report do
    association :client
    summary { "## Overall Progress\nClient is making steady progress with daily living activities.\n\n## Recommendations\nContinue current support plan." }
    report_count { 3 }

    # user_id must match a support_worker's user_id (the non-standard FK)
    transient do
      worker { association(:support_worker) }
    end

    after(:build) do |report, evaluator|
      report.user_id ||= evaluator.worker.user_id
    end
  end
end
