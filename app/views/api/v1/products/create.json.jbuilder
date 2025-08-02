# frozen_string_literal: true

json.message @message
json.product do
  json.partial! 'api/v1/products/product', product: @product
end
