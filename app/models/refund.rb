# frozen_string_literal: true

class Refund < ApplicationRecord
  has_one :order
  has_one :payment
  belongs_to :user

  validates :reason, presence: true
  validates :description, presence: true

  enum :status, { pending: 0, processing: 1, cancelled: 2, refunded: 4, rejected: 5 }, prefix: true

  def mark_as_refunded
    update!(status: :refunded)
  end

  def mark_as_processing
    update!(status: :processing)
  end

  def mark_as_cancelled
    update!(status: :cancelled)
  end

  def mark_as_refunded
    update!(status: :refunded)
  end

  def mark_as_rejected
    update!(status: :rejected)
  end
end
