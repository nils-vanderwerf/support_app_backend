class Client < ApplicationRecord
  has_many :support_workers
  has_many :appointments through: :support_workers
  has_many :support_requests
end

support_requests

client_id
appointment_id

