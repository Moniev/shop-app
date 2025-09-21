# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class InvoiceCreationService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def self.call(payment)
      new(payment: payment).call
    end

    def initialize(payment)
      @payment = payment
    end

    def call
    end

    private

    def find_order_with_details
      order_id = @payment.order_id
      Order.includes({ user: { user_detail: %i[entrepreneur_detail locations] } }, :products, :location).find(order_id)
    end

    def find_order
      @payment.order
    end
  end
end
