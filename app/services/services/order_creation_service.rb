# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class OrderCreationService
    def self.call(user)
      cart_items = user.cart_items.includes(:product)
      if cart_items.empty?
        return Services::Result.new(
          success?: false,
          errors: ['Your cart is empty.'],
          status: :unprocessable_entity,
          message: 'Order creation failed: Your cart is empty.'
        )
      end

      order = nil
      begin
        ActiveRecord::Base.transaction do
          order = user.orders.create!(status: :pending, payment_status: :unpaid)
          cart_items.update_all(order_id: order.id)

          order.reload
          order.save!
        end
        Services::Result.new(
          success?: true,
          data: { order: order },
          status: :created,
          message: 'Order created successfully from cart.'
        )
      rescue ActiveRecord::RecordInvalid => e
        Services::Result.new(
          success?: false,
          errors: order&.errors&.full_messages || e.message.split("\n"),
          status: :unprocessable_entity,
          message: 'Order creation failed due to validation errors.'
        )
      rescue StandardError => e
        Rails.logger.error("Order creation failed for user #{user.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during order creation.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end
  end
end
