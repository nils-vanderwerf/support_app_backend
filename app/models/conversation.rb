class Conversation < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker
  has_many :messages, -> { order(:created_at) }
  has_many :appointments

  def find_or_build_with(other_id, current_profile)
  end
end
