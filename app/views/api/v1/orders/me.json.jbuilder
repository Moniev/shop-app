# frozen_string_literal: true

json.cache! ['orders_me', @orders.map(&:id).sort, @orders.maximum(:updated_at) || Time.current, params[:page]] do
  json.orders @orders do |order|
    json.partial! 'api/v1/orders/order', order: order
  end

  if @orders.respond_to?(:current_page)
    json.meta do
      json.current_page @orders.current_page
      json.next_page @orders.next_page
      json.prev_page @orders.prev_page
      json.total_pages @orders.total_pages
      json.total_count @orders.total_count
    end
  end
end
