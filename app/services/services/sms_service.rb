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
    # Sends an SMS message to a specified recipient.
    #
    # This method attempts to create and send an SMS message using the Twilio API.
    # It logs success or failure with relevant details.
    #
    # @param to [String] The recipient's phone number (e.g., '+1234567890').
    # @param body [String] The content of the SMS message.
    # @return [Services::Result]
    def self.dial(to:, body:)
      unless to.present? && body.present? && twilio_phone_number.present?
        return Services::Result.new(success?: false, errors: ['Missing recipient, body, or sender number.'])
      end

      client = Twilio::REST::Client.new
      message = client.messages.create(
        from: twilio_phone_number,
        to: to,
        body: body
      )

      Rails.logger.info "SMS sent successfully to #{to}. SID: #{message.sid}"
      Services::Result.new(success?: true, data: { sid: message.sid })
    rescue Twilio::REST::TwilioError => e
      Rails.logger.error "Twilio Error: Failed to send SMS to #{to}. Reason: #{e.message}"
      Services::Result.new(success?: false, errors: [e.message])
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
    def self.dial_2fa_code(user, code)
      return Services::Result.new(success?: false, errors: ['User has no phone number.']) unless user.phone.present?

      message_body = "Your two-factor authentication code is: #{code}"
      dial(to: user.phone, body: message_body)
    end

    def self.twilio_phone_number
      ENV.fetch('TWILIO_PHONE_NUMBER')
    end
  end
end
