# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class PaymentProcessingService
    def self.call(order:, stripe_token:)
      payment = Payment.new(
        order: order,
        amount: order.total_amount,
        payment_method: 'stripe',
        status: :pending
      )

      unless payment.valid?
        return Services::Result.new(success?: false, errors: payment.errors.full_messages,
                                    status: :unprocessable_entity)
      end

      begin
        payment.save!

        charge = Stripe::Charge.create(
          amount: (payment.amount * 100).to_i,
          currency: 'PLN',
          source: stripe_token,
          description: "Order #{order.id} for user #{order.user.mail}",
          metadata: { order_id: order.id, payment_id: payment.id }
        )

        payment.update!(
          stripe_charge_id: charge.id,
          transaction_id: charge.id,
          status: :completed,
          currency: charge.currency
        )
        order.mark_as_paid!

        Services::Result.new(success?: true, data: { payment: payment }, status: :created,
                             message: 'Payment processed successfully.')
      rescue Stripe::CardError => e
        err = e.json_body[:error]
        payment.update(status: :failed, error_message: err[:message])
        Services::Result.new(success?: false, errors: [err[:message]], status: :unprocessable_entity,
                             message: 'Payment failed due to card error.')
      rescue Stripe::StripeError => e
        payment.update(status: :failed, error_message: e.message)
        Services::Result.new(success?: false, errors: [e.message], status: :internal_server_error,
                             message: 'An error occurred with the payment gateway.')
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Payment record validation failed: #{e.record.errors.full_messages.join(', ')}")
        Services::Result.new(success?: false, errors: e.record.errors.full_messages, status: :unprocessable_entity,
                             message: 'Failed to record payment.')
      rescue StandardError => e
        Rails.logger.error("Unexpected payment processing error: #{e.message}")
        payment.update(status: :failed, error_message: 'An unexpected error occurred.')
        Services::Result.new(success?: false, errors: ['An unexpected error occurred during payment processing.'],
                             status: :internal_server_error, message: 'An unexpected error occurred.')
      end
    end
  end
end
