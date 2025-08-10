# frozen_string_literal: true

json.cache! ['payments_index', @payments.map(&:id).sort,
             @payments.maximum(:updated_at) || Time.current, params[:page]] do
  json.payments @payments do |payment|
    json.partial! 'api/v1/payments/payment', payment: payment
  end

  if @payments.respond_to?(:current_page)
    json.meta do
      json.current_page @payments.current_page
      json.next_page @payments.next_page
      json.prev_page @payments.prev_page
      json.total_pages @payments.total_pages
      json.total_count @payments.total_count
    end
  end
end
