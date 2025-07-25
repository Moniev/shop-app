# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class ProductUpdateService
    def self.call(product, params)
      ActiveRecord::Base.transaction do
        product.update!(params.except(:product_photo_ids))

        ProductManagementService.assign_photos(product: product, photo_ids: params[:product_photo_ids])

        ProductCachingService.invalidate_for_product(product)
        ProductCachingService.invalidate_index_pages
      end
      Services::Result.new(
        success?: true,
        data: { product: product },
        status: :ok,
        message: 'Product updated successfully.'
      )
    rescue ActiveRecord::RecordInvalid => e
      Services::Result.new(
        success?: false,
        errors: product.errors.full_messages,
        status: :unprocessable_entity,
        message: 'Product update failed due to validation errors.'
      )
    rescue StandardError => e
      Rails.logger.error("Product update failed for ID #{product.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during product update.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
