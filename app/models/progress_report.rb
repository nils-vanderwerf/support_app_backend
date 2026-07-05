class ProgressReport < ApplicationRecord
  belongs_to :client
  belongs_to :support_worker

  validates :summary, presence: true, length: { minimum: 10 }
end
