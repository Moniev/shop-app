# frozen_string_literal: true

module Services
  class RefundCreationService
    def self.call(user, refund_params)
      return user_not_found_result unless user

      refund = Refund.new(refund_params)
      begin
        ActiveRecord::Base.transaction do
          refund.save!
        end

        Services::Result.new(
          success?: true,
          data: { refund: refund },
          status: :created,
          message: 'Refund created successfully.'
        )
      rescue ActiveRecord::RecordInvalid
        Services::Result.new(
          success?: false,
          errors: refund.errors.full_messages,
          status: :unprocessable_content,
          message: 'Refund creation failed due to validation errors.'
        )
      rescue StandardError => e
        Rails.logger.error("Refund creation failed: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during refund creation.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end
  end

  private

  def self.user_not_found_result
    Services::Result.new(
      success?: false,
      errors: ['user not found.'],
      status: :not_found,
      message: 'user not found.'
    )
  end

  def self.user_activated
    Services::Result.new(
      success?: false,
      errors: ['user is already activated'],
      status: :not_acceptable,
      message: 'user is already activated'
    )
  end

  def self.user_verified
    Services::Result.new(
      success?: false,
      errors: ['user is already verified'],
      status: :not_acceptable,
      message: 'user is already verified'
    )
  end

  private_class_method :user_not_found_result, :user_activated, :user_verified
end
