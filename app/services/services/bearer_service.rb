# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  # Handles JWT (JSON Web Token) encoding, decoding, and blacklisting operations.
  #
  # This service provides a centralized way to manage authentication tokens,
  # including setting their lifetime, interacting with Redis for token status
  # (active/blacklisted), and handling JWT-related errors.
  class BearerService
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    SECRET_KEY = Rails.application.credentials.secret_key_base
    TOKEN_LIFETIME = 24.hours.to_i
    KEY_PREFIX = 'jwt_status:'

    def self.redis
      @redis ||= Redis.current
    end

    # Encodes a payload into a JWT token and caches its active status.
    #
    # @param payload [Hash] The data to be encoded in the token (e.g., {user_id: 1}).
    # @return [Services::Result] A Result object indicating success or failure,
    #   containing the token on success or errors on failure.
    def self.encode(payload)
      payload[:exp] = Time.now.to_i + TOKEN_LIFETIME
      token = JWT.encode(payload, SECRET_KEY, 'HS256')

      begin
        redis.with { |conn| conn.set(cache_key(token), 'active', ex: TOKEN_LIFETIME) }
        Services::Result.new(
          success?: true,
          data: { token: token },
          status: :ok,
          message: 'Token encoded and cached successfully.'
        )
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error: Failed to cache JWT - #{e.message}. Token issued without Redis cache.")
        Services::Result.new(
          success?: true,
          data: { token: token },
          status: :ok,
          message: 'Token encoded, Token active via implicit means.'
        )
      rescue StandardError => e
        Rails.logger.error("Error during JWT encoding: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['Failed to encode token.'],
          status: :internal_server_error,
          message: 'Token encoding failed.'
        )
      end
    end

    # Decodes a JWT token. Checks if the token is blacklisted before decoding.
    #
    # @param token [String] The JWT token to decode.
    # @return [Services::Result] A Result object containing the decoded payload on success,
    #   or errors if the token is invalid, expired, or blacklisted.
    def self.decode(token)
      if blacklisted?(token).success? && blacklisted?(token).data[:is_blacklisted]
        return Services::Result.new(
          success?: false,
          errors: ['Token has been blacklisted.'],
          status: :unauthorized,
          message: 'Token blacklisted.'
        )
      end

      _decode_payload(token)
    end

    # Blacklists a JWT token.
    #
    # @param token [String] The JWT token to blacklist.
    # @return [Services::Result] A Result object indicating success or failure of blacklisting.
    def self.blacklist!(token)
      decoded_result = _decode_payload(token)
      unless decoded_result.success?
        return Services::Result.new(
          success?: false,
          errors: ['Invalid token for blacklisting.'],
          status: :unprocessable_content,
          message: 'Token could not be decoded for blacklisting.'
        )
      end
      decoded_payload = decoded_result.data[:payload]
      token_expires_at = Time.at(decoded_payload[:exp])

      begin
        redis_key = "jwt_status:#{token}"
        redis.with { |conn| conn.set(redis_key, 'blacklisted', ex: TOKEN_LIFETIME) }
        Services::Result.new(
          success?: true,
          status: :ok,
          message: 'Token blacklisted successfully.'
        )
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error: Failed to blacklist JWT - #{e.message}. Falling back to DB.")
        begin
          BlacklistedToken.create!(
            token: token,
            owner_id: decoded_payload[:user_id],
            expires_at: token_expires_at
          )
          Services::Result.new(
            success?: true,
            status: :ok,
            message: 'Token blacklisted successfully via database fallback.'
          )
        rescue ActiveRecord::RecordInvalid => e_db
          Rails.logger.error("DB error: Failed to blacklist JWT - #{e_db.message}")
          Services::Result.new(
            success?: false,
            errors: ["Failed to blacklist token in DB: #{e_db.message}"],
            status: :internal_server_error,
            message: 'Blacklisting failed in fallback.'
          )
        end
      rescue StandardError => e
        Rails.logger.error("Error during JWT blacklisting: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['Failed to blacklist token due to unexpected error.'],
          status: :internal_server_error,
          message: 'Blacklisting failed.'
        )
      end
    end

    # Checks if a token is blacklisted.
    #
    # @param token [String] The JWT token to check.
    # @return [Services::Result] A Result object indicating if the token is blacklisted
    #   and the status of the check (e.g., :ok, :internal_server_error).
    def self.blacklisted?(token)
      redis_key = "jwt_status:#{token}"
      begin
        status = redis.with { |conn| conn.get(redis_key) }
        is_blacklisted = (status == 'blacklisted')
        Services::Result.new(
          success?: true,
          data: { is_blacklisted: is_blacklisted },
          status: :ok,
          message: is_blacklisted ? 'Token found in blacklist' : 'Token not found in blacklist cache.'
        )
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error: Failed to check JWT blacklist - #{e.message}. Falling back to DB.")
        is_blacklisted_in_db = BlacklistedToken.exists?(token: token)
        Services::Result.new(
          success?: true,
          data: { is_blacklisted: is_blacklisted_in_db },
          status: :ok,
          message: is_blacklisted_in_db ? 'Token found in database blacklist.' : 'Token not found in database blacklist.'
        )
      rescue StandardError => e
        Rails.logger.error("Error checking JWT blacklist: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['Failed to check blacklist status.'],
          status: :internal_server_error,
          message: 'Blacklist check failed.'
        )
      end
    end

    def self.cache_key(token)
      "#{KEY_PREFIX}#{token}"
    end

    # Decodes the JWT token payload.
    #
    # @param token [String] The JWT token to decode.
    # @return [Services::Result] A Result object containing the decoded payload on success,
    #   or errors if the token is invalid or expired.
    def self._decode_payload(token)
      body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
      payload = HashWithIndifferentAccess.new(body)
      Services::Result.new(
        success?: true,
        data: { payload: payload },
        status: :ok,
        message: 'Token decoded successfully.'
      )
    rescue JWT::ExpiredSignature => e
      Rails.logger.warn("JWT Decode Error: Expired Signature - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['Token has expired.'],
        status: :unauthorized,
        message: 'Token expired.'
      )
    rescue JWT::DecodeError => e
      Rails.logger.warn("JWT Decode Error: Invalid Token - #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['Invalid token.'],
        status: :unauthorized,
        message: 'Invalid token.'
      )
    rescue StandardError => e
      Rails.logger.error("Unexpected error during JWT payload decoding: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during token decoding.'],
        status: :internal_server_error,
        message: 'Decoding failed.'
      )
    end
  end
end
