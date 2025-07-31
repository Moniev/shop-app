# frozen_string_literal: true

@data = {}

@data[:token] = token if token.present?

@data[:user] = json.partial! 'api/v1/users/user_data', user: @user if @user.present?

json.partial! 'auth', json: json
