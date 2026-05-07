class SupportWorker < ApplicationRecord
  belongs_to :user
  has_many :appointments
  has_many :admin_messages, dependent: :destroy
  has_and_belongs_to_many :specializations
  validates :first_name, :last_name, :phone, :email, :location, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: %w[pending approved rejected] }

  scope :approved, -> { where(status: 'approved') }
  scope :pending_approval, -> { where(status: 'pending') }
end
