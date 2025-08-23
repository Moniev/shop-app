# frozen_string_literal: true

json.success true
json.message @message || 'Operation successful'

json.data do
  json.merge! @data if @data.present?
end
