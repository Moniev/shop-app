# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class UserManagementService
    # Activates a user account with an activation code.
    #
    # @param user [User] The user to activate.
    # @param code [String] The activation code sent to the user.
    # @return [Services::Result] A Result object indicating success or failure of activation.
    def self.activate(user, code)
      return user_not_found_result unless user && code

      return user_activated if user.activated?

      begin
        if user.activation_code&.code == code && user.activation_code.expires_at.future?
          user.update!(active: true)
          user.activation_code.destroy!
          user.create_verification_code!(code: SecureRandom.hex(16))
          Services::Result.new(
            success?: true,
            data: { user: user },
            status: :ok,
            message: 'Account activated successfully.'
          )
        else
          Services::Result.new(
            success?: false,
            errors: ['Invalid or expired activation code.'],
            status: :unprocessable_content,
            message: 'Account activation failed: invalid or expired code.'
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Account activation failed for user #{user.id} due to validation: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: user.errors.full_messages,
          status: :unprocessable_content,
          message: 'Account activation failed due to data validation.'
        )
      rescue StandardError => e
        Rails.logger.error("Unexpected error during account activation for user #{user.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during account activation.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    # Verifies a user account with a verification code.
    #
    # @param user [User] The user to verify.
    # @param code [String] The verification code sent to the user.
    # @return [Services::Result] A Result object indicating success or failure of verification.
    def self.verify(user, code)
      return user_not_found_result unless user && code

      return user_verified unless user.unverified?

      begin
        if user.verification_code&.code == code && user.verification_code.expires_at.future?
          user.update!(verified: true)
          user.verification_code.destroy!
          Services::Result.new(
            success?: true,
            data: { user: user },
            status: :ok,
            message: 'Account verified successfully.'
          )
        else
          Services::Result.new(
            success?: false,
            errors: ['Invalid or expired verification code.'],
            status: :unprocessable_content,
            message: 'Account verification failed: invalid or expired code.'
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Account verification failed for user #{user.id} due to validation: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: user.errors.full_messages,
          status: :unprocessable_content,
          message: 'Account verification failed due to data validation.'
        )
      rescue StandardError => e
        Rails.logger.error("Unexpected error during account verification for user #{user.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during account verification.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    def self.resend_activation_code(user)
      return user_not_found_result unless user

      return user_activated unless user.unactivated?

      begin
        UserMailer.dial_activation_code(user, user.activation_code.code)
        Services::Result.new(
          success?: true,
          status: :ok,
          message: 'Activation code resent successfully'
        )
      rescue StandardError => e
        Rails.logger.error("Unexpected error during account verification for user #{user.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during account verification.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    def self.resend_verification_code(user)
      return user_not_found_result unless user

      return user_verified unless user.unverified?

      begin
        Services::SmsService.dial_verification_code(user, user.verification_code.code)
        Services::Result.new(
          success?: true,
          status: :ok,
          message: 'Verification code resent successfully'
        )
      rescue StandardError => e
        Rails.logger.error("Unexpected error during account verification for user #{user.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during account verification.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    def blacklist_user(id); end

    def whitelist_user(id); end

    private

    def self.user_not_found_result
      Services::Result.new(
        success?: false,
        errors: ['user not found.'],
        status: :not_found,
        message: 'user not found.'
      )
    end

    def self.user_activated
      Services::Result.new(
        success?: false,
        errors: ['user is already activated'],
        status: :not_acceptable,
        message: 'user is already activated'
      )
    end

    def self.user_verified
      Services::Result.new(
        success?: false,
        errors: ['user is already verified'],
        status: :not_acceptable,
        message: 'user is already verified'
      )
    end

    private_class_method :user_not_found_result, :user_activated, :user_verified
  end
end
