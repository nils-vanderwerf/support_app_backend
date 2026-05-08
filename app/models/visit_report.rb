class VisitReport < ApplicationRecord
  belongs_to :appointment
  belongs_to :support_worker, foreign_key: :user_id, primary_key: :user_id, optional: true

  validates :appointment_id, uniqueness: true
end
