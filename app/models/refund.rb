# frozen_string_literal: true

class Refund < ApplicationRecord
  has_one :order
  belongs_to :user
  has_one :payment

  validates :reason, presence: true
  validates :description, presence: true
  validates :refund_date, presence: true

  enum :status, { pending: 0, processing: 1, cancelled: 2, refunded: 4, rejected: 5 }, prefix: true, default: :pending

  scope :recent, -> { order(refund_date: :desc).limit(10) }
  scope :cancelled, -> { where(status: :cancelled) }
  scope :refunded, -> { where(status: :refunded) }
  scope :processing, -> { where(status: :processing) }
  scope :rejected, -> { where(status: :rejected) }

  def mark_as_refunded
    update!(status: :refunded)
  end

  def mark_as_processing
    update!(status: :processing)
  end

  def mark_as_cancelled
    update!(status: :cancelled)
  end

  def mark_as_rejected
    update!(status: :rejected)
  end
end
