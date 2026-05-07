class AdminMessage < ApplicationRecord
  belongs_to :support_worker

  validates :sender, inclusion: { in: %w[admin support_worker] }
  validates :content, presence: true

  scope :unread_by_worker, -> { where(sender: 'admin', read_at: nil) }
end
