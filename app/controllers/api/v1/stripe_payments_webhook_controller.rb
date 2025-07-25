# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles incoming webhooks from the Stripe payment gateway.
    #
    # This controller provides a public endpoint to receive asynchronous events
    # from Stripe, such as charge successes, failures, or refunds. It is responsible
    # for verifying the authenticity of these webhooks before processing them.
    class StripePaymentsWebhookController < ApplicationController
      skip_before_action :authenticate_user!
      # POST /api/v1/stripe_payments_webhook/handle
      #
      # Receives and processes a webhook event from Stripe.
      #
      # This action validates the webhook's signature to ensure it originated from
      # Stripe and was not tampered with. If the signature is valid, the event
      # payload is passed to the Payment model for business logic processing.
      #
      # @return [void] Sets instance variables (`@message`, `@errors`, `@status`)
      #   for the Jbuilder view, implicitly rendering `handle.json.jbuilder` with the appropriate status.
      # @see Services::StripeWebhookVerificationService.verify_and_construct_event
      # @see Services::StripeWebhookService.handle
      def handle
        payload = request.body.read
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]

        verification_result = Services::StripeWebhookVerificationService.verify_and_construct_event(
          payload: payload,
          sig_header: sig_header,
          endpoint_secret: endpoint_secret
        )

        if verification_result.success?
          event = verification_result.data[:event]
          processing_result = Services::StripeWebhookService.handle(event)
          bind_data(processing_result)
        else
          bind_data(verification_result)
        end
      end
    end
  end
end
