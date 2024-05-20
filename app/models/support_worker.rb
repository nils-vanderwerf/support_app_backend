class SupportWorker < ApplicationRecord
  has_many :appointments
  has_and_belongs_to_many :specializations
  validates :first_name, :last_name, :age, :phone, :email, :location, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
