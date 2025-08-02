# frozen_string_literal: true

module Services
  class StripeWebhookHandlerService
    def self.call(payload:, sig_header:)
      endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]

      verification_result = Services::StripeWebhookVerificationService.verify_and_construct_event(
        payload: payload,
        sig_header: sig_header,
        endpoint_secret: endpoint_secret
      )
      return verification_result unless verification_result.success?

      event = verification_result.data[:event]
      Services::StripeWebhookService.handle(event)
    end
  end
end
