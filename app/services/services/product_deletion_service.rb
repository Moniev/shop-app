# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class ProductDeletionService
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    def self.call(product)
      with_error_not_destroyed_handling do
        return not_found_result(errors: ['No such product'], message: 'Product deletion failed') unless product

        ActiveRecord::Base.transaction do
          product.destroy!

          Services::ProductCachingService.invalidate_for_product(product)
        end
        destroy_success_result(message: 'Product deleted successfully')
      end
    end
  end
end
