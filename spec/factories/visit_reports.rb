FactoryBot.define do
  factory :visit_report do
    association :appointment, :past
    date { 1.week.ago }
    activities { 'Assisted with meal preparation and daily living activities.' }
    observations { 'Client was engaged and in good spirits throughout the session.' }
    follow_up_actions { 'Schedule follow-up appointment in two weeks.' }

    # user_id and client_id are derived from the appointment automatically
    after(:build) do |report|
      report.user_id   ||= report.appointment.support_worker.user_id
      report.client_id ||= report.appointment.client_id
    end
  end
end
