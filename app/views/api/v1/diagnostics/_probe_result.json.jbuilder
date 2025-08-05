# frozen_string_literal: true

json.success @success
json.message @message
json.errors @errors if @errors.present?

if @data
  json.data do
    json.merge! @data
  end
end
