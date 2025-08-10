# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order

  enum :status, { unpaid: 0, paid: 1, failed: 2, refunded: 3 }, prefix: true, default: :unpaid

  attribute :error_message, :string

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :transaction_id, uniqueness: true, allow_nil: true
  validates :payment_method, presence: true
  validates :stripe_charge_id, presence: true, if: :status_paid?
  validates :currency, presence: true, if: :status_paid?

  before_validation :set_default_currency, on: :create

  def mark_as_paid!
    update!(status: :paid)
  end

  def mark_as_failed!(message = nil)
    update!(status: :failed, error_message: message)
  end

  def mark_as_refunded!(message = nil)
    update!(status: :refunded, error_message: message)
  end

  private

  def set_default_currency
    self.currency ||= 'PLN'
  end
end
