# frozen_string_literal: true

module Services
  class RefundDeletionService
    def self.call(refund)
      return refund_not_found_result unless refund

      begin
        ActiveRecord::Base.transaction do
          refund.destroy!
        end
        Services::Result.new(
          success?: true,
          status: :no_content,
          message: 'Refund deleted successfully.'
        )
      rescue ActiveRecord::RecordNotDestroyed => e
        Rails.logger.error("Refund deletion failed for ID #{refund.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: refund.errors.full_messages,
          status: :unprocessable_content,
          message: 'Refund deletion failed.'
        )
      rescue StandardError => e
        Rails.logger.error("Unexpected error during refund deletion for ID #{refund.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during refund deletion.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    private

    def self.refund_not_found_result
      Services::Result.new(
        success?: false,
        errors: ['refund not found.'],
        status: :not_found,
        message: 'refund not found.'
      )
    end

    private_class_method :refund_not_found_result
  end
end
