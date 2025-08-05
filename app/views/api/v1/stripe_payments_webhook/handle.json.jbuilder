# frozen_string_literal: true

if @success
  json.message @message || 'Webhook processed successfully.'
else
  json.errors @errors || ['An unexpected error occurred.']
  json.message @message if @message.present?
end
