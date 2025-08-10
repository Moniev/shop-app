# frozen_string_literal: true

json.cache! ['refund_partial', refund.id, refund.updated_at] do
  json.id refund.id
  json.order_id refund.order_id
  json.status refund.status
  json.reason refund.reason
  json.description refund.description
  json.created_at refund.created_at
  json.updated_at refund.updated_at
end
