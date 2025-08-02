# frozen_string_literal: true

json.message 'User entrepreneur details updated successfully.'
if @user.user_detail&.entrepreneur_detail.present?
  json.entrepreneur_detail do
    json.partial! 'api/v1/users/entrepreneur_details', entrepreneur_detail: @user.user_detail.entrepreneur_detail
  end
end
