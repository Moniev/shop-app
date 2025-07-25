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
    def self.call(product)
      ActiveRecord::Base.transaction do
        product.destroy!

        ProductCachingService.invalidate_index_pages
      end
      Services::Result.new(
        success?: true,
        status: :no_content,
        message: 'Product deleted successfully.'
      )
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error("Product deletion failed for ID #{product.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: product.errors.full_messages,
        status: :unprocessable_entity,
        message: 'Product deletion failed.'
      )
    rescue StandardError => e
      Rails.logger.error("Unexpected error during product deletion for ID #{product.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during product deletion.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
