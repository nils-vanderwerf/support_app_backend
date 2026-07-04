FactoryBot.define do
  factory :progress_report do
    association :client
    summary { "## Overall Progress\nClient is making steady progress with daily living activities.\n\n## Recommendations\nContinue current support plan." }
    report_count { 3 }

    transient do
      worker { association(:support_worker) }
    end

    after(:build) do |report, evaluator|
      report.support_worker_id ||= evaluator.worker.id
    end
  end
end
