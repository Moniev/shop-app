# frozen_string_literal: true

if @errors.present?
  json.status @status
  json.errors @errors
  json.details @data&.dig(:details)
else
  json.status @status
  json.message @message
  json.details @data&.dig(:details)
end
