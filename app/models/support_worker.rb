class SupportWorker < ApplicationRecord
  belongs_to :user
  has_many :appointments
  has_many :admin_messages, dependent: :destroy
  has_and_belongs_to_many :specialisations
  validates :first_name, :last_name, :phone, :email, :location, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: %w[pending approved rejected] }

  scope :approved, -> { where(status: 'approved') }
  scope :pending_approval, -> { where(status: 'pending') }

  def age
    return nil unless date_of_birth
    today = Date.today
    a = today.year - date_of_birth.year
    a -= 1 if today < date_of_birth + a.years
    a
  end
end
