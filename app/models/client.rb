class Client < ApplicationRecord
  belongs_to :user
  has_many :support_workers
  has_many :appointments

  validates :first_name, :last_name, presence: true

  def age
    return nil unless date_of_birth
    today = Date.today
    a = today.year - date_of_birth.year
    a -= 1 if today < date_of_birth + a.years
    a
  end
end