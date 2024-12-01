class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { client: 0, support_worker: 1, both: 2 }

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 1 }
end