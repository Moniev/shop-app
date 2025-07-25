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
    INDEX_KEYS_SET = 'products:index_cache_keys'

    def self.fetch_all(page = 1)
      cache_key = "products:page:#{page}:#{Product.maximum(:updated_at).to_i}"

      begin
        Redis.current.sadd(INDEX_KEYS_SET, cache_key)

        Rails.cache.fetch(cache_key, expires_in: 12.minutes) do
          Product.includes(:product_photos, :likes, :comments).page(page).per(25).to_a
        end
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during fetch_all: #{e.message}")
        Product.includes(:product_photos, :likes, :comments).page(page).per(25).to_a
      end
    end

    def self.fetch_one(id)
      product = Product.find_by(id: id)
      return nil unless product

      begin
        Rails.cache.fetch(product, expires_in: 1.hour) do
          product.class.includes(:product_photos, :likes, :comments).find(product.id)
        end
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during fetch_one: #{e.message}")
        product.class.includes(:product_photos, :likes, :comments).find(product.id)
      end
    end

    def self.invalidate_for_product(product)
      Rails.cache.delete(product)
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error during cache invalidation for product #{product.id}: #{e.message}")
    end

    def self.invalidate_index_pages
      keys_to_delete = Redis.current.smembers(INDEX_KEYS_SET)

      if keys_to_delete.any?
        Rails.cache.delete_multi(keys_to_delete)
        Redis.current.del(INDEX_KEYS_SET)
      end
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error during cache invalidation: #{e.message}")
    end
  end
end
