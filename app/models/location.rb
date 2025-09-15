# frozen_string_literal: true

class Location < ApplicationRecord
  belongs_to :user_detail, optional: true

  validates :country, :province, :city, :postal_code, presence: true
  validates :building_number, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :apartment_number, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
end
