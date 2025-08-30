# frozen_string_literal: true

require 'twilio-ruby'

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  # Encapsulates SMS sending functionality using the Twilio API.
  #
  # This service provides methods to send general SMS messages and specific
  # two-factor authentication (2FA) codes to users via their phone numbers.
  # It handles Twilio client initialization and error logging for failed attempts.
  class SmsService
    class << self
      # Sends an SMS message to a specified recipient.
      #
      # This method attempts to create and send an SMS message using the Twilio API.
      # It logs success or failure with relevant details.
      #
      # @param to [String] The recipient's phone number (e.g., '+1234567890').
      # @param body [String] The content of the SMS message.
      # @return [Services::Result]
      def dial(to:, body:)
        return false if to.blank? || body.blank?

        return false unless twilio_available?

        msg = client.messages.create(
          from: from_number,
          to: to,
          body: body
        )
        Rails.logger.info("SMS sent successfully. SID=#{msg.sid}")
        true
      rescue Twilio::REST::TwilioError => e
        Rails.logger.error("Twilio Error: Failed to send SMS: #{e.message}")
        false
      rescue StandardError => e
        Rails.logger.error("Twilio Error: Failed to send SMS: #{e.message}")
        false
      end

      # Sends a two-factor authentication (2FA) code via SMS to a user.
      #
      # This method constructs a standard 2FA message and uses the `dial` method
      # to send it to the user's registered phone number. The message is only sent
      # if the user has a phone number associated with their account.
      #
      # @param user [User] The user object to whom the 2FA code should be sent.
      #   The user object must respond to a `phone` method.
      # @param code [String] The 2FA code to be sent.
      # @return [Boolean, nil] True if the message was successfully sent, false if Twilio error,
      #   or nil if the user has no phone number.
      def dial_2fa_code(user, code)
        return false if user.phone.blank?

        dial(to: user.phone, body: "Your two-factor authentication code is: #{code}")
      end

      def dial_verification_code(user, code)
        return false if user.phone.blank?

        dial(to: user.phone, body: "Your verification code is #{code}")
      end

      private

      def client
        TWILIO_CLIENT
      end

      def from_number
        ENV.fetch('TWILIO_PHONE_NUMBER', {})
      end

      def twilio_available?
        if defined?(TWILIO_CLIENT) && TWILIO_CLIENT
          true
        else
          Rails.logger.warn('Twilio client is not available')
          false
        end
      end
    end
  end
end
