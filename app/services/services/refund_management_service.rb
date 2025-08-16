# frozen_string_literal: true

module Services
  class RefundManagementService
    def initialize(order)
      @order = order
    end

    def update_order_status(update_order_params)
      ActiveRecord::Base.transaction do
        @order.update(update_order_params)
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
