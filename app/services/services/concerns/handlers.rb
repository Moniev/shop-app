# frozen_string_literal: true

module Services
  module Concerns
    module Handlers
      def with_error_handling(_ = nil)
        yield
      rescue ActiveRecord::RecordNotFound
        user_not_found_result
      rescue ActiveRecord::RecordInvalid => e
        invalid_record_result(e)
      rescue StandardError => e
        unknown_error_result(e)
      end
    end
  end
end
