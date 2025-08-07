# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :product_photos, dependent: :destroy
  has_many :comments, dependent: :destroy, inverse_of: :product
  has_many :product_likes, dependent: :destroy
  has_many :product_rates, dependent: :destroy

  accepts_nested_attributes_for :product_photos, allow_destroy: true
  validates :name, presence: true

  scope :with_details, -> { includes(:product_photos, :comments, :product_likes, :product_rates) }
end
