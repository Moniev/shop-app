# frozen_string_literal: true

class Item < ApplicationRecord
  belongs_to :order, optional: true
  belongs_to :user, optional: true
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price_at_purchase, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :must_belong_to_user_or_order
  after_commit :recalculate_order_total, on: %i[create update destroy]

  private

  def must_belong_to_user_or_order
    errors.add(:base, 'Item must belong to a user (for cart) or an order') unless user_id.present? || order_id.present?
    return unless user_id.present? && order_id.present?

    errors.add(:base, 'Item cannot belong to both a user (cart) and an order simultaneously')
  end

  def recalculate_order_total
    return unless order.present?

    order.send(:calculate_total_amount)
    order.save!
  end
end
