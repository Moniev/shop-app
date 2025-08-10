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
    def self.call(params)
      product = Product.new(params.except(:product_photo_ids))

      begin
        ActiveRecord::Base.transaction do
          product.save!
          ProductManagementService.assign_photos(product: product, photo_ids: params[:product_photo_ids])

          ProductCachingService.invalidate_index_pages
        end
        Services::Result.new(
          success?: true,
          data: { product: product },
          status: :created,
          message: 'Product created successfully.'
        )
      rescue ActiveRecord::RecordInvalid => e
        Services::Result.new(
          success?: false,
          errors: product.errors.full_messages,
          status: :unprocessable_content,
          message: 'Product creation failed due to validation errors.'
        )
      rescue StandardError => e
        Rails.logger.error("Product creation failed: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during product creation.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end
  end
end
