# frozen_string_literal: true

json.cache! ['payment_show', @payment.id, @payment.updated_at, @payment.order&.updated_at] do
  json.message @message if @message.present?
  json.payment do
    json.partial! 'payment', payment: @payment
  end
end
