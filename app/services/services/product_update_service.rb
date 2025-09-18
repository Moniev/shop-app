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
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.call(product, params)
      with_error_handling do
        ActiveRecord::Base.transaction do
          product.update!(params.except(:product_photo_ids))

          ProductManagementService.assign_photos(product: product, photo_ids: params[:product_photo_ids])

          ProductCachingService.invalidate_for_product(product)
          ProductCachingService.invalidate_index_pages
        end
        success_result(data: { product: product }, message: 'Product updated successfully')
      end
    end
  end
end
