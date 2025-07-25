# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class StripeWebhookVerificationService
    def self.verify_and_construct_event(payload:, sig_header:, endpoint_secret:)
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
      Services::Result.new(
        success?: true,
        data: { event: event },
        status: :ok,
        message: 'Webhook event verified successfully.'
      )
    rescue JSON::ParserError => e
      Rails.logger.error("Stripe Webhook Error: Invalid payload - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['Invalid webhook payload.'],
        status: :bad_request,
        message: 'Invalid payload.'
      )
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("Stripe Webhook Error: Signature verification failed - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['Stripe signature verification failed.'],
        status: :bad_request,
        message: 'Signature verification failed.'
      )
    rescue StandardError => e
      Rails.logger.error("Stripe Webhook Error: Unexpected error during event construction - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during webhook processing.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
