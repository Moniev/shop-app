# frozen_string_literal: true

module Services
  module Concerns
    module Handlers
      def with_error_handling(_ = nil)
        yield
      rescue ActiveRecord::RecordNotFound
        user_not_found_result
      rescue ActiveRecord::RecordInvalid => e
        invalid_record_result(e)
      rescue StandardError => e
        unknown_error_result(e)
      end

      def with_error_not_destroyed_handling
        yield
      rescue ActiveRecord::RecordNotFound
        not_found_result(errors: ['Record hasnt been found'], message: 'Failed to find such record')
      rescue ActiveRecord::RecordNotDestroyed => e
        record_not_destroyed_error_result(exc: e, record: e.record)
      rescue ActiveRecord::RecordInvalid => e
        invalid_record_result(e)
      rescue StandardError => e
        unknown_error_result(e)
      end

      def with_json_parser_error_handling
        yield
      rescue JSON::ParserError
        json_parser_error_result(errors: ['Invalid webhook payload'], message: 'Invalid payload')
      rescue Stripe::SignatureVerificationError
        stripe_verification_error_result(errors: ['Stripe signature verification failed.'],
                                         message: 'Signature verification failed')
      rescue StandardError => e
        unknown_error_result(e)
      end

      def with_webhook_error_handling
        yield
      rescue StandardError => e
        Rails.logger.error("Webhook: Error processing Stripe event. #{e.message}")
        Services::Result.new(
          success?: false,
          status: :internal_server_error,
          message: 'Webhook processing failed.'
        )
      end

      def with_twilio_error_handling
        yield
      rescue Twilio::REST::TwilioError => e
        Rails.logger.error("Twilio Error: Failed to send SMS: #{e.message}")
        false
      rescue StandardError => e
        Rails.logger.error("Twilio Error: Failed to send SMS: #{e.message}")
        false
      end
    end
  end
end
