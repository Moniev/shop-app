# frozen_string_literal: true

json.message @message
json.order do
  json.partial! 'api/v1/orders/order', order: @order
end
