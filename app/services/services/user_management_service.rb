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
    extend Concerns::CodeValidation
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    # Activates a user account with an activation code.
    #
    # @param user [User] The user to activate.
    # @param code [String] The activation code sent to the user.
    # @return [Services::Result] A Result object indicating success or failure of activation.
    def self.activate(user, code)
      return user_not_found_result unless user
      return user_already_activated_result unless user.unactivated?

      with_error_handling do
        validate_and_execute_code(user.activation_code, code, 'activation') do
          user.update!(active: true)
          user.create_verification_code!(code: SecureRandom.hex(16))
          success_result(data: { user: user }, message: 'Account activated successfully.')
        end
      end
    end

    # Verifies a user account with a verification code.
    #
    # @param user [User] The user to verify.
    # @param code [String] The verification code sent to the user.
    # @return [Services::Result] A Result object indicating success or failure of verification.
    def self.verify(user, code)
      return user_not_found_result unless user
      return user_already_verified_result unless user.unverified?

      with_error_handling do
        validate_and_execute_code(user.verification_code, code, 'verification') do
          user.update!(verified: true)
          success_result(data: { user: user }, message: 'Account verified successfully.')
        end
      end
    end

    def self.resend_activation_code(user)
      return user_not_found_result unless user
      return user_already_activated_result unless user.unactivated?

      with_error_handling(user) do
        UserMailer.dial_activation_code(user, user.activation_code.code).deliver_later
        success_result(user, 'Activation code resent successfully')
      end
    end

    def self.resend_verification_code(user)
      return user_not_found_result unless user
      return user_verified unless user.unverified?

      with_error_handling(user) do
        Services::SmsService.dial_verification_code(user, user.verification_code.code)
        success_result(user, 'Verification code resent successfully')
      end
    end

    def self.blacklist_user(id:)
      with_error_handling(id) do
        user = User.find_by(id)
        user.update(blacklisted: true)
        user.save!
        sucess_result(user)
      end
    end

    def self.whitelist_user(id:)
      with_error_handling(id) do
        user = User.find_by(id)
        user.update(blacklisted: false)
        user.save!
        success_result(user)
      end
    end
  end
end
