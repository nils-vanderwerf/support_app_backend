class Specialisation < ApplicationRecord
  has_and_belongs_to_many :support_workers
end
