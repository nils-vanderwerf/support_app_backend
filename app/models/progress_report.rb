class ProgressReport < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker, foreign_key: :user_id, primary_key: :user_id, optional: true

  validates :summary, presence: true
end
