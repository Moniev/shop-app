# frozen_string_literal: true

json.message @message
json.order do
  json.partial! 'order', order: @order
end
