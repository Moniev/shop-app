# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :destroy
  has_many :products, through: :items
  has_one :payment, dependent: :destroy
  has_one :refund, dependent: :destroy

  enum :status, { pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4, refunded: 5 }, prefix: true,
                                                                                                    default: :pending
  enum :payment_status, { unpaid: 0, paid: 1, failed: 2, refunded: 3 }, prefix: true, default: :unpaid

  accepts_nested_attributes_for :items, allow_destroy: true

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :payment_status, presence: true
  validates :order_date, presence: true

  before_validation :set_order_date, on: :create
  before_save :calculate_total_amount

  scope :recent, -> { order(order_date: :desc).limit(10) }
  scope :completed, -> { where(status: :delivered) }
  scope :pending_payment, -> { where(payment_status: :unpaid) }

  def self.for_user(user)
    return none unless user

    if user.admin?
      includes(:user, :items).order(created_at: :desc)
    else
      user.orders.includes(:items).order(created_at: :desc)
    end
  end

  def self.create_from_cart_for(user)
    cart_items = user.cart_items.includes(:product)

    return { order: nil, errors: ['Your cart is empty'] } if cart_items.empty?

    order = nil
    transaction do
      order = user.orders.create!
      cart_items.update_all(order_id: order.id, user_id: nil)

      order.reload
      order.save!
    end

    { order: order, errors: [] }
  rescue ActiveRecord::RecordInvalid => e
    { order: nil, errors: [e.message] }
  end

  def total_items_count
    items.sum(:quantity)
  end

  def accessible_by?(user)
    self.user == user || user.admin?
  end

  def manageable_by?(user)
    user.admin?
  end

  def mark_as_paid!
    update!(payment_status: :paid)
  end

  def mark_as_failed!
    update!(payment_status: :failed)
  end

  def mark_as_refunded!
    update!(payment_status: :refunded)
  end

  def total_in_cents
    (total_amount * 100).to_i
  end

  private

  def set_order_date
    self.order_date ||= Time.current
  end

  def calculate_total_amount
    self.total_amount = items.reject(&:marked_for_destruction?).sum do |item|
      (item.price_at_purchase || 0) * (item.quantity || 0)
    end
  end
end
