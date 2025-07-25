# frozen_string_literal: true

require 'jwt'
# Namespace for API resources and controllers.
module Api
  # Base controller for the API.
  #
  # Provides shared functionality for all API controllers, including authentication,
  # authorization, global exception handling, and setting the default response format.
  class ApplicationController < ActionController::API
    around_action :measure_execution_time
    before_action :set_default_response_format
    before_action :authenticate_user!

    class Unauthorized < StandardError; end
    class Forbidden < StandardError; end
    class BadRequest < StandardError; end

    def measure_execution_time
      start_time = Time.now
      yield
      end_time = Time.now

      duration = end_time - start_time
      Rails.logger.info "Action #{action_name} from controller #{controller_name} took #{duration.round(2)} seconds."
    end

    rescue_from ActiveRecord::RecordNotFound do |exception|
      Rails.logger.warn "RecordNotFound: #{exception.message}"
      render json: { errors: [exception.message], message: 'Resource not found.' }, status: :not_found
    end

    rescue_from ActiveRecord::RecordInvalid do |exception|
      Rails.logger.warn "RecordInvalid: #{exception.record.errors.full_messages.join(', ')}"
      render json: { errors: exception.record.errors.full_messages, message: 'Validation failed.' },
             status: :unprocessable_entity
    end

    rescue_from ArgumentError, BadRequest do |exception|
      Rails.logger.warn "BadRequest/ArgumentError: #{exception.message}"
      render json: { errors: [exception.message], message: 'Bad request parameters.' }, status: :bad_request
    end

    rescue_from Unauthorized do |exception|
      Rails.logger.warn "Unauthorized access: #{exception.message}"
      render json: { errors: [exception.message], message: 'Authentication required or invalid credentials.' },
             status: :unauthorized
    end

    rescue_from Forbidden do |exception|
      Rails.logger.warn "Forbidden access: #{exception.message}"
      render json: { errors: [exception.message], message: 'Access denied.' }, status: :forbidden
    end

    rescue_from StandardError do |exception|
      Rails.logger.error "Unhandled exception: #{exception.message}\n#{exception.backtrace.join("\n")}"
      render json: { errors: ['An unexpected error occurred.'], message: 'Internal server error.' },
             status: :internal_server_error
    end

    # Initializes the CanCanCan Ability object for the current user.
    # This is used by `load_and_authorize_resource` for authorization.
    #
    # @return [Ability] The Ability object for the current user.
    def current_ability
      @current_ability ||= Ability.new(current_user)
    end

    # A `before_action` filter to restrict access to admin users only.
    # **NOTE**: With CanCanCan's `load_and_authorize_resource`, this method might become redundant
    # if your abilities file correctly handles admin-only access for resources/actions.
    #
    # @raise [Api::Forbidden] If the current user is not an admin.
    def authorize_admin!
      raise Api::Forbidden, 'Admin access required.' unless current_user&.admin?
    end

    # Memoizes and returns the authenticated user for the current request.
    # Finds the user based on the user_id from the decoded JWT payload.
    #
    # @return [User, nil] The authenticated user instance or nil if not found.
    def current_user
      return unless @decoded_jwt_token&.success?

      @current_user ||= User.find_by(id: @decoded_jwt_token&.data&.dig(:payload,
                                                                       :user_id))
    end

    # The primary authentication filter for securing endpoints.
    # This is a `before_action` that ensures the request is authenticated.
    # If authentication fails, it renders an error response and halts the request.
    #
    # @raise [Api::Unauthorized] If the token is missing, invalid, or user not found.
    # @raise [Api::Forbidden] If the user's account is not active or verified.
    # @return [void]
    def authenticate_user!
      token = request.headers['Authorization']&.split&.last
      token_decode_result = Services::BearerService.decode(token || '')

      unless token_decode_result.success?
        render json: { errors: token_decode_result.errors, message: token_decode_result.message },
               status: token_decode_result.status
        return false
      end

      @decoded_jwt_token = token_decode_result

      unless current_user
        render json: { errors: ['Authentication failed: User not found.'], message: 'User not found.' },
               status: :unauthorized
        return false
      end

      unless current_user.active? && current_user.verified?
        render json: { errors: ['User account is not active or verified.'], message: 'Account not active or verified.' },
               status: :forbidden
        return false
      end
      true
    end

    # Binds common data from a service result object to controller instance variables
    # and sets the HTTP response status. This method is used by child controllers.
    #
    # @param result [Services::Result] The result object from a service call.
    # @return [void]
    def bind_data(result)
      @message ||= result.message
      @errors ||= result.errors
      @status = result.status
      response.status = @status
    end

    protected

    attr_reader :decoded_jwt_token

    # A `before_action` filter to force the request format to JSON.
    # This ensures consistent API responses.
    #
    # @return [void]
    def set_default_response_format
      request.format = :json
    end
  end
end
