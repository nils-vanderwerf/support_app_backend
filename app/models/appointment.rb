class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :support_workers
end
