# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class PasswordResetService
    def self.request(email)
      user = User.find_by(mail: email)
      if user
        code = SecureRandom.hex(16)
        expires_at = 2.hours.from_now

        redis_key = "password_reset:#{code}"
        begin
          Redis.current.set(redis_key, user.id, ex: 2.hours.to_i)
        rescue Redis::CannotConnectError => e
          Rails.logger.error("Redis error during password reset request: #{e.message}")
          user.reset_code&.destroy
          user.create_reset_code!(code: code, expires_at: expires_at)
        end
      end

      Services::Result.new(
        success?: true,
        message: 'If an account exists, instructions have been sent to your email.',
        status: :ok
      )
    end

    def self.reset(reset_code, password, password_confirmation)
      user = find_user_by_reset_code(reset_code)

      unless user
        return Services::Result.new(
          success?: false,
          errors: ['Invalid or expired reset code.'],
          message: 'Invalid or expired password reset code.',
          status: :unprocessable_entity
        )
      end

      unless password == password_confirmation
        return Services::Result.new(
          success?: false,
          errors: ['Password and confirmation do not match.'],
          message: 'Password and confirmation do not match.',
          status: :unprocessable_entity
        )
      end

      begin
        if user.update(password: password, password_confirmation: password_confirmation)
          begin
            Redis.current.del("password_reset:#{reset_code}")
          rescue Redis::CannotConnectError => e
            Rails.logger.error("Redis error during password reset cleanup: #{e.message}")
          end
          user.reset_code&.destroy

          Services::Result.new(
            success?: true,
            message: 'Password has been reset successfully.',
            status: :ok
          )
        else
          Services::Result.new(
            success?: false,
            errors: user.errors.full_messages,
            message: 'Password reset failed due to validation errors.',
            status: :unprocessable_entity
          )
        end
      rescue StandardError => e
        Rails.logger.error("Unexpected error during password reset for user ID #{user.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during password reset.'],
          message: 'An unexpected error occurred.',
          status: :internal_server_error
        )
      end
    end

    private

    def self.find_user_by_reset_code(code)
      user_id = nil
      begin
        user_id = Redis.current.get("password_reset:#{code}")
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during password reset code lookup: #{e.message}")
      end

      if user_id
        user = User.find_by(id: user_id)
        return user
      else
        reset = ResetCode.find_by(code: code)
        return reset.user if reset&.expires_at&.future?
      end
      nil
    end
  end
end
