# frozen_string_literal: true

json.cache! ['product_show', @product.id, @product.updated_at] do
  json.product do
    json.partial! 'api/v1/products/product', product: @product
  end
end
