# frozen_string_literal: true

json.cache! ['cart', current_user, @cart_items.maximum(:updated_at)] do
  json.success @errors.blank?
  json.message @message if @message.present?
  json.errors @errors if @errors.present?

  json.data do
    json.total_amount @total_amount
    json.items_count @items_count

    json.items @cart_items do |item|
      json.item_id item.id
      json.quantity item.quantity
      json.price_at_purchase item.price_at_purchase
      json.subtotal item.quantity * item.price_at_purchase

      json.product do
        json.id item.product.id
        json.name item.product.name
      end
    end
  end
end
