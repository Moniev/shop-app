# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class ProductCachingService
    INDEX_KEY_PREFIX = 'products:page'
    VERSION_KEY = 'products:version'

    def self.fetch_all(page = 1)
      cache_key = index_cache_key(page)
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        Product.with_details.includes(:product_photos, :product_likes, :comments)
               .page(page).per(25).to_a
      end
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error in fetch_all, falling back to DB: #{e.message}")
      Product.with_details.includes(:product_photos, :product_likes, :comments)
             .page(page).per(25).to_a
    end

    def self.fetch_one(id)
      Rails.cache.fetch("product:#{id}", expires_in: 1.hour) do
        Product.with_details.includes(:product_photos, :product_likes, :comments).find_by(id: id)
      end
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error in fetch_one, falling back to DB: #{e.message}")
      Product.with_details.includes(:product_photos, :product_likes, :comments).find_by(id: id)
    end

    def self.invalidate_for_product(product)
      Rails.cache.delete("product:#{product.id}")
      invalidate_index_pages
    end

    def self.invalidate_index_pages
      Rails.cache.delete_matched("#{INDEX_KEY_PREFIX}:*")
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error in invalidate_index_pages: #{e.message}")
    end

    private

    def self.index_cache_key(page)
      version = Rails.cache.fetch(VERSION_KEY) { 1 }
      "#{INDEX_KEY_PREFIX}:#{page}:#{version}"
    end

    private_class_method :index_cache_key
  end
end
