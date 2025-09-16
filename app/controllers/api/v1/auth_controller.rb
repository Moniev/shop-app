# frozen_string_literal: true

require 'jwt'

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles user authentication-related operations.
    #
    # Provides endpoints for login, two-factor authentication (2FA), account
    # activation, and password reset. Responses are rendered using Jbuilder templates.
    class AuthController < Api::ApplicationController
      include Api::V1::Concerns::TokenResendable

      skip_before_action :authenticate_user!
      before_action :set_user_by_mail, only: %i[
        verify_2fa
        activate
        verify
        request_2fa_code_resend
        request_activation_code_resend
        request_verification_code_resend
      ]

      # POST /api/v1/auth/login
      #
      # Authenticates a user based on email and password.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :password The user's password.
      #
      # @return [void] Sets instance variables (`@user`, `@token`, `@message`, `@errors`, `@status`)
      #   for the Jbuilder view (`login.json.jbuilder`).
      # @see Services::AuthenticationService.login
      def login
        result = Services::AuthenticationService.login(params[:mail], params[:password])
        bind_data_and_render(result, 'login')
      end

      # POST /api/v1/auth/verify_2fa
      #
      # Verifies a two-factor authentication (2FA) code.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :second_factor_code The 2FA code sent to the user.
      #
      # @return [void] Sets instance variables (`@token`, `@errors`, `@status`)
      #   for the Jbuilder view (`verify_2fa.json.jbuilder`).
      # @see Services::AuthenticationService.verify_2fa
      def verify_2fa
        result = Services::AuthenticationService.verify_2fa(@user, params[:second_factor_code])
        bind_data_and_render(result, 'verify_2fa', user: @user)
      end

      # PATCH /api/v1/auth/activate
      #
      # Activates a user account with an activation code.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :activation_code The activation code sent to the user.
      #
      # @return [void] Sets instance variables (`@message`, `@errors`, `@status`)
      #   for the Jbuilder view (`activate.json.jbuilder`).
      # @see Services::AccountManagementService.activate
      def activate
        result = Services::UserManagementService.activate(@user, params[:activation_code])
        bind_data_and_render(result, 'activate', user: @user)
      end

      # PATCH /api/v1/auth/verify
      #
      # Verifies a user account with a verification code.
      #
      # @param [String] :mail The user's email address.
      # @param [String] :verification_code The verification code sent to the user.
      #
      # @return [void] Sets instance variables (`@message`, `@errors`, `@status`)
      #   for the Jbuilder view (`verify.json.jbuilder`).
      # @see Services::AccountManagementService.verify
      def verify
        result = Services::UserManagementService.verify(@user, params[:verification_code])
        bind_data_and_render(result, 'verify', user: @user)
      end

      # POST /api/v1/auth/password/reset
      #
      # Initiates the password reset process.
      #
      # @param [String] :mail The user's email address.
      #
      # @return [void] Sets instance variables (`@message`, `@status`)
      #   for the Jbuilder view (`request_reset.json.jbuilder`).
      # @see Services::PasswordResetService.request
      def request_reset
        result = Services::PasswordResetService.request(params[:mail])
        bind_data_and_render(result, 'request_reset')
      end

      # PATCH /api/v1/auth/password/reset
      #
      # Confirms a password reset using a code.
      #
      # @param [String] :reset_code The reset code sent to the user.
      # @param [String] :password The new password.
      # @param [String] :password_confirmation The new password confirmation.
      #
      # @return [void] Sets instance variables (`@message`, `@errors`, `@status`)
      #   for the Jbuilder view (`confirm_reset.json.jbuilder`).
      # @see Services::PasswordResetService.reset
      def confirm_reset
        result = Services::PasswordResetService.reset(params[:reset_code], params[:password],
                                                      params[:password_confirmation])
        bind_data_and_render(result, 'confirm_reset')
      end

      def blacklist_user
        result = Services::UserManagementService.blacklist_user(params[:user_id])
        bind_data_and_render(result, 'blacklist_user')
      end

      def whitelist_user
        result = Services::UserManagementService.whitelist_user(params[:user_id])
        bind_data_and_render(result, 'whitelist_user')
      end

      private

      def bind_data_and_render(result, view_name, locals = {})
        bind_data(result)
        @token = @data[:token] if @data.is_a?(Hash)
        render view_name, status: @status, locals: locals.merge(token: @token)
      end

      # Defines permitted parameters for creating a user.
      # This is a "strong parameters" method to protect against mass assignment.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[first_name last_name]
        )
      end
    end
  end
end
