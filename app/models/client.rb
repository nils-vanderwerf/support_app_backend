class Client < ApplicationRecord
  belongs_to :user
  has_many :support_workers
  has_many :appointments
  has_many :reviews, dependent: :destroy

  validates :first_name, :last_name, presence: true

  # Fields safe to show any approved worker before an appointment is established —
  # enough to judge fit and decide whether to reach out. support_needs is a
  # deliberately curated summary for exactly this purpose; the raw medical record
  # (medication, allergies) and contact info (phone, email) stay behind an
  # approved appointment.
  PUBLIC_ATTRIBUTES = %w[id first_name last_name location bio health_conditions support_needs].freeze

  # Medication, allergies, and contact info (phone, email) only go out once an
  # approved appointment establishes a real relationship between the worker and
  # this client.
  def as_json_for(full:)
    full ? as_json(methods: [:age]) : as_json(only: self.class::PUBLIC_ATTRIBUTES, methods: [:age])
  end

  def age
    return nil unless date_of_birth
    today = Date.today
    a = today.year - date_of_birth.year
    a -= 1 if today < date_of_birth + a.years
    a
  end
end