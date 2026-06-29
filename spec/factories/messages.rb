FactoryBot.define do
  factory :message do
    association :conversation
    sender_type { 'client' }
    sender_id { association(:client).id }
    # Content is stored encrypted in production; in tests use a plaintext stub
    content { 'Hello, I need some assistance.' }

    trait :from_support_worker do
      sender_type { 'support_worker' }
    end

    trait :system_message do
      content { '[SYS] Appointment confirmed for next Monday at 10am.' }
    end

    trait :encrypted do
      content { 'ENC:dGVzdA==.abc123.def456' }
    end
  end
end
