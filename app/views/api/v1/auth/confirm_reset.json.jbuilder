# frozen_string_literal: true

if @errors
  json.message @message
  json.errors @errors
  json.status @status
else
  json.message @message
  json.status @status
end
