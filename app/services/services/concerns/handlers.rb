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

      def with_json_parser_error_handling(_ = nil)
        yield
      rescue JSON::ParserError
        json_parser_error_result(errors: ['Invalid webhook payload'], message: 'Invalid payload')
      rescue Stripe::SignatureVerificationError
        stripe_verification_error_result(errors: ['Stripe signature verification failed.'],
                                         message: 'Signature verification failed')
      rescue StandardError => e
        unknown_error_result(e)
      end
    end
  end
end
