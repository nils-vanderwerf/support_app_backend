class FailedEmailLog < ApplicationRecord
  scope :unresolved, -> { where(resolved_at: nil) }

  def resolve!
    update!(resolved_at: Time.current)
  end
end
