# frozen_string_literal: true

module Services
  class StripeWebhookService
    # Handles incoming Stripe webhook events.
    #
    # @param event [Stripe::Event] The event object from Stripe.
    # @return [Services::Result] A Result object.
    def self.handle(event)
      case event.type
      when 'charge.succeeded'
        handle_charge_succeeded(event.data.object)
      when 'charge.failed'
        handle_charge_failed(event.data.object)
      when 'charge.refunded'
        handle_charge_refunded(event.data.object)
      else
        Rails.logger.warn("Webhook: Unhandled Stripe event type: #{event.type}")
        Services::Result.new(success?: false, status: :bad_request, message: "Unhandled event type: #{event.type}")
      end
    rescue StandardError => e
      Rails.logger.error("Webhook: Error processing Stripe event #{event.id} (#{event.type}): #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ["Error processing Stripe event: #{e.message}"],
        message: "Failed to process webhook for event type: #{event.type}",
        status: :internal_server_error
      )
    end

    private

    def self.handle_charge_succeeded(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return Services::Result.new(success?: true, status: :ok, message: 'Payment not found.') unless payment
      return Services::Result.new(success?: true, status: :ok, message: 'Payment already paid.') if payment.status_paid?

      ActiveRecord::Base.transaction do
        payment.update!(status: :paid)
        payment.order.update!(payment_status: :paid)
      end

      Rails.logger.info "Webhook: Charge succeeded for Payment ##{payment.id}"
      Services::Result.new(success?: true, status: :ok)
    end

    def self.handle_charge_failed(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return Services::Result.new(success?: true, status: :ok, message: 'Payment not found.') unless payment

      if payment.status_failed?
        return Services::Result.new(success?: true, status: :ok,
                                    message: 'Payment already failed.')
      end

      failure_message = charge.failure_message || 'Charge failed for an unknown reason.'

      ActiveRecord::Base.transaction do
        payment.update!(status: :failed, error_message: failure_message)
        payment.order.update!(payment_status: :failed)
      end

      Rails.logger.info "Webhook: Charge failed for Payment ##{payment.id}"
      Services::Result.new(success?: true, status: :ok)
    end

    def self.handle_charge_refunded(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return Services::Result.new(success?: true, status: :ok, message: 'Payment not found.') unless payment

      if payment.status_refunded?
        return Services::Result.new(success?: true, status: :ok,
                                    message: 'Payment already refunded.')
      end

      ActiveRecord::Base.transaction do
        payment.update!(status: :refunded)
        payment.order.update!(status: :refunded, payment_status: :refunded)
      end

      Rails.logger.info "Webhook: Charge refunded for Payment ##{payment.id}"
      Services::Result.new(success?: true, status: :ok)
    end
  end
end
