class Specialization < ApplicationRecord
  has_and_belongs_to_many :support_workers
end
