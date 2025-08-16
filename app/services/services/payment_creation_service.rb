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
    def self.call(user:, order_id:)
      order = user.orders.find_by(id: order_id)

      return order_not_found_result unless order
      return order_already_paid_result if order.payment_status_paid?

      begin
        payment_intent = find_or_create_payment_intent(order)

        Services::Result.new(
          success?: true,
          data: { client_secret: payment_intent.client_secret },
          status: :ok,
          message: 'PaymentIntent created successfully.'
        )
      rescue Stripe::StripeError => e
        Rails.logger.error("Stripe error for order #{order.id}: #{e.message}")
        stripe_error_result(e)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Validation error for order #{order.id}: #{e.message}")
        validation_error_result(e)
      end
    end

    private

    def self.find_or_create_payment_intent(order)
      if order.stripe_payment_intent_id
        Stripe::PaymentIntent.update(
          order.stripe_payment_intent_id,
          amount: order.total_in_cents,
          currency: 'pln'
        )
      else
        payment_intent = Stripe::PaymentIntent.create(
          amount: order.total_in_cents,
          currency: 'pln',
          metadata: { order_id: order.id }
        )
        order.update!(stripe_payment_intent_id: payment_intent.id)
        payment_intent
      end
    end

    def self.order_not_found_result
      Services::Result.new(
        success?: false,
        errors: ['Order not found or does not belong to the user.'],
        status: :not_found
      )
    end

    def self.order_already_paid_result
      Services::Result.new(
        success?: false,
        errors: ['This order has already been paid for.'],
        status: :unprocessable_content
      )
    end

    def self.stripe_error_result(error)
      Services::Result.new(
        success?: false,
        errors: ['Could not connect to the payment provider. Please try again later.'],
        status: :service_unavailable,
        message: error.message
      )
    end

    def self.validation_error_result(error)
      Services::Result.new(
        success?: false,
        errors: error.record.errors.full_messages,
        status: :unprocessable_content
      )
    end
  end
end
