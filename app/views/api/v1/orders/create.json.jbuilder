# frozen_string_literal: true

if @errors.blank?
  json.message 'Order created successfully.'
  json.order do
    json.partial! 'order', order: @order
  end
else
  json.errors @errors
end
