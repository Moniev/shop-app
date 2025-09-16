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
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.verify_and_construct_event(payload:, sig_header:, endpoint_secret:)
      with_json_parser_error_handling do
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
        success_result(data: { event: event }, message: 'Webhook event verified successfully')
      end
    end
  end
end
