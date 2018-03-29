class Patient < ApplicationRecord
  include ActiveRecord::PessimisticLocking
  has_many :appointments
  has_many :prescriptions
  has_many :physicians, through: :appointments
end
