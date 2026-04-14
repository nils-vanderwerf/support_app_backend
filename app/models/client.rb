class Client < ApplicationRecord
  belongs_to :user
  has_many :support_workers
  has_many :appointments,through: :support_workers
  has_many :support_requests
end