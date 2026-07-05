class SupportWorker < ApplicationRecord
  belongs_to :user
  has_many :appointments
  has_many :reviews, dependent: :destroy
  has_many :admin_messages, dependent: :destroy
  has_and_belongs_to_many :specialisations
  validates :first_name, :last_name, :phone, :email, :location, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: %w[pending approved rejected] }
  validates :state, inclusion: { in: WwccValidator::STATES }, allow_nil: true

  enum :state, WwccValidator::STATES.index_with(&:itself), prefix: :state

  scope :approved, -> { where(status: 'approved') }
  scope :pending_approval, -> { where(status: 'pending') }

  def average_rating
    return nil if reviews.empty?
    (reviews.average(:rating) || 0).round(1)
  end

  def review_count
    reviews.count
  end

  # Whether an appointment between this worker and the given client has ever been
  # approved — upcoming or in the past, regardless of the appointment's own date.
  def approved_appointment_with?(client)
    appointments.approved.exists?(client_id: client.id)
  end

  def age
    return nil unless date_of_birth
    today = Date.today
    a = today.year - date_of_birth.year
    a -= 1 if today < date_of_birth + a.years
    a
  end
end
