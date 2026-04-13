class Client < ApplicationRecord
  has_many :support_workers
  has_many :appointments
end