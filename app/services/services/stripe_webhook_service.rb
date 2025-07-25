# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class StripeWebhookService
    def self.handle(event)
      charge = event.data.object
      case event.type
      when 'charge.succeeded'
        process_charge_succeeded(charge)
      when 'charge.failed'
        process_charge_failed(charge)
      when 'charge.refunded'
        process_charge_refunded(charge)
      else
        Rails.logger.warn "Webhook: Unhandled Stripe event type: #{event.type}"
        return Services::Result.new(
          success?: true,
          message: "Unhandled Stripe event type: #{event.type}",
          status: :ok
        )
      end
      Services::Result.new(success?: true, message: "Webhook handled successfully for event type: #{event.type}",
                           status: :ok)
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

    def self.process_charge_succeeded(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return unless payment
      return if payment.completed?

      ActiveRecord::Base.transaction do
        payment.mark_as_completed!
        payment.order.mark_as_paid!
      end
      Rails.logger.info "Webhook: Stripe charge succeeded for Payment ##{payment.id}"
    end

    def self.process_charge_failed(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return unless payment
      return if payment.failed?

      failure_message = charge.failure_message || 'Charge failed for an unknown reason.'
      ActiveRecord::Base.transaction do
        payment.mark_as_failed!(failure_message)
        payment.order.update!(payment_status: :failed)
      end
      Rails.logger.info "Webhook: Stripe charge failed for Payment ##{payment.id}"
    end

    def self.process_charge_refunded(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return unless payment
      return if payment.refunded?

      ActiveRecord::Base.transaction do
        payment.update!(status: :refunded)
        payment.order.update!(status: :refunded, payment_status: :refunded)
      end
      Rails.logger.info "Webhook: Stripe charge refunded for Payment ##{payment.id}"
    end
  end
end
