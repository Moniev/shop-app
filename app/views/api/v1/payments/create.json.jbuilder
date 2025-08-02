# frozen_string_literal: true

json.message @message if @message.present?
json.payment do
  json.partial! 'payment', payment: @payment
end
