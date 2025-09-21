class Invoice < ApplicationRecord
  belongs_to :user

  has_one :order
  has_one :location
  has_one :payment
  has_many :invoice_items
  has_many :products, through: :invoice_items

  validates :invoice_number, :tax_rate, :tax_value, presence: true
  validates :total_gross, :total_net, presence: true
end
