# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class ProductManagementService
    def self.assign_photos(product:, photo_ids:)
      return if photo_ids.blank?

      ids = Array(photo_ids).reject(&:blank?)
      ProductPhoto.where(id: ids, product_id: nil).update_all(product_id: product.id)
    end
  end
end
