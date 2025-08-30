# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  has_many :items, dependent: :destroy
  has_many :products, through: :items
  has_one :payment, dependent: :destroy
  has_one :refund, dependent: :destroy
  belongs_to :location

  enum :status, { pending: 0, processing: 1, shipped: 2, delivered: 3, cancelled: 4, refunded: 5 }, prefix: true,
                                                                                                    default: :pending
  enum :payment_status, { unpaid: 0, paid: 1, failed: 2, refunded: 3 }, prefix: true, default: :unpaid
  enum :package_carrier, { dpd: 0, inpost: 1, fedex: 2, dhl: 3, ups: 4, pp: 5 }, default: :inpost

  accepts_nested_attributes_for :items, allow_destroy: true

  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :payment_status, presence: true
  validates :order_date, presence: true
  validates :package_carrier, presence: true

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

  def self.create_from_cart_for(user:, location_id:, package_carrier:)
    cart_items = user.cart_items.includes(:product)
    user_location = user.user_detail&.locations&.find_by(id: location_id)

    return { order: nil, errors: ['Your cart is empty'] } if cart_items.empty?
    return { order: nil, errors: ['Invalid location'] } unless user_location

    order = nil
    transaction do
      order_location = user_location.dup
      order_location.user_detail_id = nil
      order_location.save!

      order = user.orders.build(location: order_location, package_carrier: package_carrier)
      order.items = cart_items
      order.save!

      Item.where(id: order.item_ids).update_all(user_id: nil)
    end

    { order: order, errors: [] }
  rescue ActiveRecord::RecordInvalid => e
    { order: nil, errors: [e.message] }
  end

  def to_order_dto
    {
      id: id,
      carrier: package_carrier,
      receiver: build_receiver_payload,
      package: build_package_payload,
      context: build_context_payload
    }
  end

  def build_receiver_payload
    {
      contact: build_receiver_contact_payload,
      address: build_receiver_address_payload
    }
  end

  def build_receiver_contact_payload
    detail = user.user_detail
    company_detail = detail.entrepreneur_detail
    {
      company_name: company_detail&.business_name || '',
      person_name: "#{detail&.first_name} #{detail&.last_name}",
      phone: user.phone,
      email: user.mail,
      nip: company_detail&.nip
    }
  end

  def build_receiver_address_payload
    return {} unless location

    {
      street: "#{location.street} #{location.building_number}" + (location.apartment_number ? "/#{location.apartment_number}" : ''),
      postal_code: location.postal_code,
      city: location.city,
      country_code: location.country,
      point_id: ''
    }
  end

  def build_package_payload
    {
      weight_kg: items.joins(:product).sum('items.quantity * products.weight_kg').round(2),
      length_cm: products.maximum(:length_cm) || 0,
      width_cm: products.maximum(:width_cm) || 0,
      height_cm: products.maximum(:height_cm) || 0,
      type: package_type || 'parcel'
    }
  end

  def build_context_payload
    {
      value_in_grosz: total_in_cents,
      content: products.map(&:name).join(', '),
      comment: notes || "Order nr: #{id}",
      pickup_details: {}
    }
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
