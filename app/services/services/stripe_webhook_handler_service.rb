# frozen_string_literal: true

module Services
  class StripeWebhookHandlerService
    def self.call(payload:, sig_header:)
      endpoint_secret = ENV.fetch('STRIPE_WEBHOOK_SECRET')
      unless endpoint_secret
        Rails.logger.error('StripeWebhookHandlerService: Missing Stripe webhook secret in credentials.')
        return Services::Result.new(
          success?: false,
          errors: ['Stripe webhook secret is not configured on the server.'],
          status: :internal_server_error
        )
      end

      verification_result = Services::StripeWebhookVerificationService.verify_and_construct_event(
        payload: payload,
        sig_header: sig_header,
        endpoint_secret: endpoint_secret
      )

      return verification_result unless verification_result.success?

      event = verification_result.data[:event]
      Services::StripeWebhookService.handle(event)
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("StripeWebhookHandlerService: Webhook signature verification failed - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['Webhook signature verification failed. Invalid signature.'],
        status: :bad_request
      )
    rescue StandardError => e
      Rails.logger.error("StripeWebhookHandlerService: Unexpected error - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while processing the webhook.'],
        status: :internal_server_error
      )
    end
  end
end
