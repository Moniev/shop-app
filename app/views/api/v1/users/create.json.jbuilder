# frozen_string_literal: true

if @user.present?
  json.message @message || 'User created successfully.'
  json.user do
    json.partial! 'api/v1/users/user_data', user: @user
  end
  json.status @status || :created
else
  json.message @message || 'User creation failed.'
  json.errors @errors
  json.status @status || :unprocessable_entity
end
