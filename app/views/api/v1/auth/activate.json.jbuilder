# frozen_string_literal: true

@data = {}
@data[:user] = json.partial! 'api/v1/users/user_data', user: @user if @success && @user

json.partial! 'auth', json: json
