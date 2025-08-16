# frozen_string_literal: true

module Services
  class RefundManagementService
    def initialize(refund)
      @refund = refund
    end

    def cancel
      return wrong_refund_status unless @refund.status_pending? || @refund.status_processing?

      if @refund.update(status: :cancelled)
        Services::Result.new(
          success?: true,
          data: { refund: @refund },
          status: :ok,
          message: 'Refund cancelled successfully.'
        )
      else
        Services::Result.new(
          success?: false,
          errors: @refund.errors.full_messages,
          status: :unprocessable_content,
          message: 'Refund cancellation failed due to validation errors.'
        )
      end
    rescue StandardError => e
      Rails.logger.error("Refund cancellation failed for refund ID #{@refund.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during order cancellation.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def complete
      return wrong_refund_status if @refund.status_rejected? || @refund.status_pending?

      begin
        ActiveRecord::Base.transaction do
          @refund.update!(status: :refunded)
        end
        Services::Result.new(
          success?: true,
          data: { refund: @refund },
          status: :ok,
          message: 'Refund completed successfully.'
        )
      rescue ActiveRecord::RecordInvalid => e
        Services::Result.new(
          success?: false,
          errors: e.record.errors.full_messages,
          status: :unprocessable_content,
          message: 'Failed to complete refund due to validation errors.'
        )
      rescue StandardError => e
        Rails.logger.error("Refund completion failed for refund ID #{@refund.id}: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during refund completion'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    def mark_refund_status(status)
      mark_status(:status, status, Refund.statuses)
    end

    def mark_payment_status(status)
      mark_status(:payment_status, status, Refund.payment_statuses)
    end

    def mark_status(attribute, status, valid_statuses)
      status_key = status.to_s
      unless valid_statuses.key?(status_key)
        return Services::Result.new(
          success?: false,
          errors: ["'#{status_key}' is not a valid #{attribute}."],
          status: :unprocessable_content,
          message: 'Invalid status provided.'
        )
      end

      if @refund.update(attribute => status_key)
        Services::Result.new(
          success?: true,
          data: { refund: @refund },
          status: :ok,
          message: "Refund #{attribute} successfully updated to '#{status_key}'."
        )
      else
        Services::Result.new(
          success?: false,
          errors: @refund.errors.full_messages,
          status: :unprocessable_content,
          message: "Failed to update refund #{attribute}."
        )
      end
    rescue StandardError => e
      Rails.logger.error("Failed to update #{attribute} for refund #{@refund.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ["An unexpected error occurred while updating the refund #{attribute}."],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def wrong_refund_status
      Services::Result.new(
        success?: false,
        errors: ["Cannot cancel refund with status: #{@refund.status}"],
        status: :unprocessable_content,
        message: "Cannot cancel refund with status: #{@refund.status}."
      )
    end
  end
end
