class SupportWorker < ApplicationRecord
  has_many :appointments
  validates :first_name, :last_name, :age, :phone, :email, :location, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
