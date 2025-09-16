# frozen_string_literal: true

module Services
  module Concerns
    module CodeValidation
      def validate_and_execute_code(code_record, code, message_context)
        unless code_record&.code == code && code_record.expires_at.future?
          return Services::Result.new(
            success?: false,
            errors: ["Invalid or expired #{message_context} code."],
            status: :unprocessable_content,
            message: "Account #{message_context} failed: invalid or expired code."
          )
        end

        ActiveRecord::Base.transaction do
          result = yield
          code_record.destroy!
          result
        end
      end
    end
  end
end
