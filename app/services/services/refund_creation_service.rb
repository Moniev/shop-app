# frozen_string_literal: true

module Services
  class RefundCreationService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.call(user, refund_params)
      with_error_handling do
        return not_found_result(errors: ['User not found'], message: 'User not found') unless user

        ActiveRecord::Base.transaction do
          refund = Refund.new(refund_params)
          refund.save!
        end

        success_result(data: { refund: refund }, message: 'Refund created successfully')
      end
    end
  end
end
