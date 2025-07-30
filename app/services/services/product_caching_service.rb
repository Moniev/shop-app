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
    INDEX_KEY_PREFIX = 'products:page'

    def self.fetch_all(page = 1)
      cache_key = index_cache_key(page)

      redis_command { Redis.current.sadd(INDEX_KEYS_SET, cache_key) }

      cache_command do
        Rails.cache.fetch(cache_key, expires_in: 12.minutes) do
          Product.with_details.page(page).per(25).to_a
        end
      end
    end

    def self.fetch_one(id)
      product = Product.find_by(id: id)
      return nil unless product

      cache_command do
        Rails.cache.fetch(product, expires_in: 1.hour) do
          Product.with_details.find(product.id)
        end
      end
    end

    def self.invalidate_for_product(product)
      cache_command { Rails.cache.delete(product) }
    end

    def self.invalidate_index_pages
      keys_to_delete = redis_command { Redis.current.smembers(INDEX_KEYS_SET) }
      return if keys_to_delete.blank?

      cache_command { Rails.cache.delete_multi(keys_to_delete) }
      redis_command { Redis.current.del(INDEX_KEYS_SET) }
    end

    private

    def self.index_cache_key(page)
      timestamp = Product.maximum(:updated_at).to_i
      "#{INDEX_KEY_PREFIX}:#{page}:#{timestamp}"
    end

    def self.redis_command(&block)
      yield
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis command failed: #{e.message}")
      nil
    end

    def self.cache_command(&block)
      yield
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Rails.cache command failed, falling back to database: #{e.message}")
      yield if block.source_location.to_s.include?('fetch')
    end
  end
end
