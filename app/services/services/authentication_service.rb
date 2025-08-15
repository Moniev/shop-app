# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class AuthenticationService
    # Authenticates a user based on email and password.
    #
    # @param email [String] The user's email address.
    # @param password [String] The user's password.
    # @return [Services::Result] A Result object indicating success or failure of login.
    def self.login(email, password)
      user = User.find_by(mail: email)
      unless user&.active?
        return Result.new(
          success?: false,
          errors: ['User is not activated.'],
          status: :unauthorized,
          message: 'Authentication failed.'
        )
      end

      unless user&.authenticate(password)
        return Result.new(
          success?: false,
          errors: ['Invalid email or password.'],
          status: :unauthorized,
          message: 'Authentication failed.'
        )
      end

      if user.two_factor_enabled?
        send_2fa_code(user)
        Result.new(
          success?: true,
          message: 'Two-factor authentication code sent. Please verify.',
          status: :accepted,
          data: { user_id: user.id }
        )
      else
        token_result = BearerService.encode({ user_id: user.id })
        if token_result.success?
          Result.new(
            success?: true,
            data: { token: token_result.data[:token] },
            status: :ok,
            message: 'Logged in successfully.'
          )
        else
          token_result
        end
      end
    rescue StandardError => e
      Rails.logger.error("Login process failed for email #{email}: #{e.message}")
      Result.new(
        success?: false,
        errors: ['An unexpected error occurred during login.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    # Verifies a two-factor authentication (2FA) code for a user.
    #
    # @param user [User] The user object.
    # @param code [String] The 2FA code.
    # @return [Services::Result] A Result object indicating success or failure of 2FA verification.
    def self.verify_2fa(user, code)
      return user_not_found_result unless user

      redis_key = "user:#{user.id}:2fa_code"

      begin
        if BearerService.redis.with { |conn| conn.get(redis_key) } == code
          code_from_redis_matches = true
          BearerService.redis.with { |conn| conn.del(redis_key) }
          user.second_factor_code&.destroy
          token_result = BearerService.encode({ user_id: user.id })
          return Result.new(
            success?: true,
            data: { token: token_result.data[:token] },
            status: :ok,
            message: '2FA verified successfully.'
          )
        end
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during 2FA verify for user #{user.id}: #{e.message}. Falling back to DB check.")
      end

      if user.second_factor_code&.code == code
        user.second_factor_code.destroy
        token_result = BearerService.encode({ user_id: user.id })
        return Result.new(
          success?: true,
          data: { token: token_result.data[:token] },
          status: :ok,
          message: '2FA verified successfully via database.'
        )
      end

      Result.new(
        success?: false,
        errors: ['Invalid 2FA code.'],
        status: :unauthorized,
        message: 'Invalid two-factor authentication code.'
      )
    rescue StandardError => e
      Rails.logger.error("2FA verification process failed for user #{user.id}: #{e.message}")
      Result.new(
        success?: false,
        errors: ['An unexpected error occurred during 2FA verification.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    # Blacklists a user's JWT token.
    # This method is designed to be called from the UsersController's logout action.
    #
    # @param token [String] The JWT token to blacklist.
    # @return [Services::Result] A Result object indicating success or failure of token blacklisting.
    def self.blacklist_token(token)
      BearerService.blacklist!(token)
    end

    private

    # Sends a two-factor authentication code to the user.
    #
    # @param user [User] The user object.
    def self.send_2fa_code(user)
      return user_not_found_result unless user

      code = SecureRandom.hex(8)
      redis_key = "user:#{user.id}:2fa_code"
      expires_at = 15.minutes.from_now

      begin
        BearerService.redis.with { |conn| conn.set(redis_key, code, ex: 15.minutes.to_i) }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during 2FA code send for user #{user.id}: #{e.message}. Falling back to DB.")
        user.second_factor_code&.destroy
        user.create_second_factor_code!(code: code, expires_at: expires_at)
      rescue StandardError => e
        Rails.logger.error("Unexpected error creating 2FA code for user #{user.id}: #{e.message}")
      end

      if user.phone.present?
        SmsService.dial_2fa_code(user, code)
      else
        UserMailer.dial_2fa_code(user, code).deliver_later
      end
    end

    def self.user_not_found_result
      Services::Result.new(
        success?: false,
        errors: ['user not found.'],
        status: :not_found,
        message: 'user not found.'
      )
    end
    private_class_method :send_2fa_code, :user_not_found_result
  end
end
