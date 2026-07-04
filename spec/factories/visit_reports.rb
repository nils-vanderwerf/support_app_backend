FactoryBot.define do
  factory :visit_report do
    association :appointment, :past
    date { 1.week.ago }
    activities { 'Assisted with meal preparation and daily living activities.' }
    observations { 'Client was engaged and in good spirits throughout the session.' }
    follow_up_actions { 'Schedule follow-up appointment in two weeks.' }

    after(:build) do |report|
      report.support_worker_id ||= report.appointment.support_worker.id
      report.client_id         ||= report.appointment.client_id
    end
  end
end
