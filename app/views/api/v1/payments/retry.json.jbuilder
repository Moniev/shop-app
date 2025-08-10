# frozen_string_literal: true

json.message @message if @message.present?
json.payment do
  json.partial! 'api/v1/payments/payment', payment: @payment
end
