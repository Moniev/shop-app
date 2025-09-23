# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class CartService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def initialize(user)
      @user = user
    end

    def check_parameters(product_id, quantity)
      product = Product.find_by(id: product_id)
      return not_found_result(errors: ['Product not found'], message: 'Product not found') unless product

      quantity = quantity.to_i
      return product if quantity.positive?

      unprocessable_content_with_errors_result(errors: ['Product must be greater than 0'],
                                               message: 'Product quantity mu be greater than 0')
    end

    def process_cart(product, quantity)
      cart_item = @user.cart_items.find_or_initialize_by(product: product)
      if cart_item.new_record?
        cart_item.quantity = quantity
      else
        cart_item.quantity += quantity
      end

      cart_item.price_at_purchase = product.price
      cart_item.save!

      success_result(data: { product: product }, message: 'Product added to cart successfully')
    end

    # Adds a product to the user's cart.
    # Handles product lookup and quantity validation internally.
    #
    # @param product_id [String] The ID of the product to add.
    # @param quantity [Integer] The quantity to add.
    # @return [Services::Result] An object indicating success/failure and relevant data/errors.
    def add_product(product_id, quantity)
      with_error_handling do
        result = check_parameters(product_id, quantity)
        return result if result.errors.any?

        process_cart(result, quantity)
      end
    end

    # Removes or decrements a product from the user's cart.
    # Handles cart item lookup and quantity validation internally.
    #
    # @param item_id [String] The ID of the cart item to modify.
    # @param quantity_to_remove [Integer, nil] The quantity to remove, or nil to remove all.
    # @return [Services::Result] An object indicating success/failure and relevant data/errors.
    def remove_product(item_id, quantity_to_remove = nil)
      item = @user.cart_items.find_by(id: item_id)
      return product_not_found unless item

      quantity_to_remove = quantity_to_remove.to_i if quantity_to_remove.present?

      begin
        if quantity_to_remove.present? && quantity_to_remove.positive? && quantity_to_remove < item.quantity
          item.decrement!(:quantity, quantity_to_remove)
          Services::Result.new(success?: true, message: 'Product quantity updated in cart.', status: :ok)
        elsif quantity_to_remove.present? && quantity_to_remove.positive? && quantity_to_remove >= item.quantity
          item.destroy!
          Services::Result.new(success?: true, message: 'Product removed from cart.', status: :ok)
        elsif quantity_to_remove.nil?
          item.destroy!
          Services::Result.new(success?: true, message: 'Product removed from cart.', status: :ok)
        else
          Services::Result.new(
            success?: false,
            errors: ['Quantity to remove must be positive or nil to remove all.'],
            status: :unprocessable_content,
            message: 'Invalid quantity to remove.'
          )
        end
      rescue StandardError => e
        Rails.logger.error("Failed to remove product from cart: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred while removing the product from the cart.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    # Clears all items from the user's cart.
    # @return [Services::Result] An object indicating success/failure and relevant data/errors.
    def clear
      @user.cart_items.destroy_all
      Services::Result.new(success?: true, message: 'Cart cleared successfully.', status: :ok)
    rescue StandardError => e
      Rails.logger.error("Failed to clear cart: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while clearing the cart.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    # Retrieves the current state of the user's cart.
    #
    # @return [Hash] A hash containing cart items, total amount, and items count.
    def get_cart_summary
      cart_items = @user.cart_items.includes(:product)
      total_amount = cart_items.sum { |item| item.quantity * item.price_at_purchase }
      items_count = cart_items.sum(:quantity)
      {
        cart_items: cart_items,
        total_amount: total_amount,
        items_count: items_count
      }
    end

    private

    def product_not_found
      Services::Result.new(
        success?: false,
        errors: ['Cart item not found.'],
        status: :not_found,
        message: 'Cart item not found.'
      )
    end
  end
end
