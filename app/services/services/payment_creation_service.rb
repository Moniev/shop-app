# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class PaymentCreationService
    def self.call(user:, order_id:, stripe_token:)
      order = user.orders.find_by(id: order_id)

      unless order
        return Services::Result.new(
          success?: false,
          errors: ['Order not found or does not belong to the user.'],
          status: :not_found,
          message: 'Order not found or does not belong to the user.'
        )
      end

      if order.payment_status_paid?
        return Services::Result.new(
          success?: false,
          errors: ['This order has already been paid for.'],
          status: :unprocessable_entity,
          message: 'This order has already been paid for.'
        )
      end

      Services::PaymentProcessingService.call(order: order, stripe_token: stripe_token)
    end
  end
end
