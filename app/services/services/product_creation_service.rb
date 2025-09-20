# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class ProductCreationService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.call(params)
      with_error_handling do
        product = Product.new(params.except(:product_photo_ids))
        ActiveRecord::Base.transaction do
          product.save!
          ProductManagementService.assign_photos(product: product, photo_ids: params[:product_photo_ids])

          ProductCachingService.invalidate_for_product(product) if product.present?
        end
        success_result(data: { product: product }, message: 'Product created successfully', status: :created)
      end
    end
  end
end
