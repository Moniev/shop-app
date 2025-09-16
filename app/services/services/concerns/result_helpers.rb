# frozen_string_literal: true

module Services
  module Concerns
    module ResultHelpers
      def user_not_found_result
        Services::Result.new(
          success?: false,
          errors: ['User not found.'],
          status: :not_found,
          message: 'User not found.'
        )
      end

      def user_already_activated_result
        Services::Result.new(
          success?: false,
          errors: ['User is already activated'],
          status: :not_acceptable,
          message: 'User is already activated'
        )
      end

      def unknown_error_result(exc)
        Rails.logger.error("An unexpected error occurred: #{exc.message}")
        Services::Result.new(
          success?: false,
          errors: ['Unknown error has occured during the operation'],
          status: :internal_server_error,
          message: ''
        )
      end

      def invalid_record_result(exc)
        Rails.logger.error("Validation failed: #{exc.message}")
        Services::Result.new(
          success?: false,
          errors: e.record.error_messages,
          status: :unprocessable_content,
          message: 'Validation failed'
        )
      end

      def success_result(data:, message:)
        Rails.logger.info("Successfully finished operation: #{message}")
        Services::Result.new(
          success?: true,
          data: data,
          status: :ok,
          message: message
        )
      end

      def unprocessable_content_result(record:, message:)
        Rails.logger.error("Failed to validate processing data: #{message}")
        Services::Result.new(
          success?: false,
          errors: record.errors.full_messages,
          status: :unprocessable_content,
          message: message
        )
      end

      def destroy_success_result(message:)
        Rails.logger.info("Record destroyed: #{message}")
        Services::Result.new(
          success?: false,
          status: :no_content,
          message: message
        )
      end

      def unauthorized_result(errors:, message:)
        Rails.logger.info("User is not authorized for this action: #{message}")
        Services::Result.new(
          success?: false,
          status: :authorized,
          errors: errors,
          message: message
        )
      end
    end
  end
end
