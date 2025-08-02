# frozen_string_literal: true

json.message 'Order updated successfully.'
json.order do
  json.partial! 'order', order: @order
end
