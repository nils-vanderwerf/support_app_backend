class Message < ApplicationRecord
  belongs_to :conversation
  validates :content, presence: true
  validates :sender_type, inclusion: { in: %w[client support_worker] }
end
