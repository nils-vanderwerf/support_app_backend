class Client < ApplicationRecord
  belongs_to :user
  has_many :support_workers
  has_many :appointments

  validates :first_name, :last_name, presence: true
end