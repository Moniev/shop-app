# frozen_string_literal: true

module Services
  class StripeWebhookService
    def self.handle(event)
      case event.type
      when 'payment_intent.succeeded'
        handle_payment_intent_succeeded(event.data.object)
      when 'payment_intent.payment_failed'
        handle_payment_intent_failed(event.data.object)
      when 'charge.refunded'
        handle_charge_refunded(event.data.object)
      else
        no_action_needed("Unhandled event type: #{event.type}")
      end
    rescue StandardError => e
      Rails.logger.error("Webhook: Error processing Stripe event #{event.id} (#{event.type}): #{e.message}")
      Services::Result.new(success?: false, status: :internal_server_error, message: 'Webhook processing failed.')
    end

    def self.handle_payment_intent_succeeded(payment_intent)
      order = Order.find_by(stripe_payment_intent_id: payment_intent.id)

      unless order
        Rails.logger.error("Webhook Error: Could not find Order for succeeded PI #{payment_intent.id}")
        return Services::Result.new(success?: false, status: :not_found, message: 'Order not found for PI.')
      end

      return no_action_needed("Order ##{order.id} is already marked as paid.") if order.payment_status_paid?

      ActiveRecord::Base.transaction do
        Payment.create_from_payment_intent(payment_intent)
        order.mark_as_paid!
      end

      log_and_return_success("Successfully processed payment for Order ##{order.id}.")
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error("Webhook Error processing succeeded PI #{payment_intent.id}: #{e.message}")
      Services::Result.new(success?: false, status: :internal_server_error, message: e.message)
    end

    def self.handle_payment_intent_failed(payment_intent)
      order = Order.find_by(stripe_payment_intent_id: payment_intent.id)
      return no_action_needed("Order not found for failed PI #{payment_intent.id}") unless order

      order.mark_as_failed!
      log_and_return_success("Marked Order ##{order.id} as failed.")
    end

    def self.handle_charge_refunded(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return no_action_needed("Payment not found for refunded Charge #{charge.id}") unless payment
      return no_action_needed("Payment ##{payment.id} already refunded.") if payment.status_refunded?

      ActiveRecord::Base.transaction do
        payment.mark_as_refunded!
        payment.order.mark_as_refunded!
      end

      log_and_return_success("Processed refund for Payment ##{payment.id}.")
    end

    def self.no_action_needed(message)
      Rails.logger.info "Webhook: #{message}"
      Services::Result.new(success?: true, status: :ok, message: message)
    end

    def self.log_and_return_success(message)
      Rails.logger.info "Webhook: #{message}"
      Services::Result.new(success?: true, status: :ok, message: message)
    end
  end
end
