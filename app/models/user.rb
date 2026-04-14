class User < ApplicationRecord
  has_one :client
  has_one :support_worker
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { client: 0, support_worker: 1, both: 2 }

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 1 }, if: -> { password.present? }
  validates :password, presence: true, on: :create
end