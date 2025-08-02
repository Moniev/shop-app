# frozen_string_literal: true

json.message 'User location updated successfully.'
if @user.user_detail&.locations.present?
  json.location do
    json.partial! 'api/v1/users/location', location: @user.user_detail.locations.first
  end
end
