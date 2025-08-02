# frozen_string_literal: true

json.message @message
json.product do
  json.id @product.id
  json.likes_count @product.product_likes.count
end
