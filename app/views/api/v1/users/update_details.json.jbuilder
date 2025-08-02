# frozen_string_literal: true

json.message 'User details updated successfully.'
if @user.user_detail.present?
  json.user_detail do
    json.partial! 'api/v1/users/user_detail', user_detail: @user.user_detail
  end
end
