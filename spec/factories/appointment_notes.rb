FactoryBot.define do
  factory :appointment_note do
    association :appointment, :past
    content { 'Client was engaged throughout. Completed daily living tasks and discussed goals. Blood pressure stable, good mood overall.' }

    after(:build) do |note|
      note.support_worker_id ||= note.appointment.support_worker.id
    end
  end
end
