# frozen_string_literal: true

require 'twilio-ruby'

Twilio.configure do |config|
  config.account_sid = ENV.fetch('TWILIO_ACCOUNT_SID')
  config.auth_token = ENV.fetch('TWILIO_AUTH_TOKEN')
end

if config.account_sid && config.auth_token
  TWILIO_CLIENT = Twilio::REST::Client.new(config.account_sid, config.auth_token)
  Rails.logger.info 'Twilio client initialized successfully.'
else
  Rails.logger.warn 'Twilio credentials not found. SMSService will not be available.'
end
