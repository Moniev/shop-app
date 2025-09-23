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

      success_result(data: nil, message: 'Product added to cart successfully')
    end

    # Adds a product to the user's cart.
    # Handles product lookup and quantity validation internally.
    #
    # @param product_id [String] The ID of the product to add.
    # @param quantity [Integer] The quantity to add.
    # @return [Services::Result] An object indicating success/failure and relevant data/errors.
    def add(product_id, quantity)
      with_error_handling do
        ActiveRecord::Base.transaction do
          result = check_parameters(product_id, quantity)
          return result if result.errors.any?

          return process_cart(result, quantity)
        end
      end
    end

    # Removes or decrements a product from the user's cart.
    # Handles cart item lookup and quantity validation internally.
    #
    # @param item_id [String] The ID of the cart item to modify.
    # @param quantity_to_remove [Integer, nil] The quantity to remove, or nil to remove all.
    # @return [Services::Result] An object indicating success/failure and relevant data/errors.
    def remove(item_id, quantity_to_remove = nil)
      with_error_handling do
        ActiveRecord::Base.transaction do
          item = @user.cart_items.find_by(id: item_id)
          return success_result(data: nil, message: 'Product not in cart') if item.nil?

          quantity = quantity_to_remove&.to_i
          return invalid_quantity_result if quantity.present? && !quantity.positive?

          perform_removal(item, quantity)
        end
      end
    end

    def invalid_quantity_result
      unprocessable_content_with_errors_result(
        errors: ['Quantity to remove must be a positive number.'], message: 'Invalid quantity'
      )
    end

    def perform_removal(item, quantity)
      if quantity.nil? || quantity >= item.quantity
        item.destroy!
        message = 'Product removed from cart'
      else
        item.decrement!(:quantity, quantity)
        message = 'Product quantity updated in cart'
      end
      success_result(data: nil, message: message, status: :ok)
    end

    # Clears all items from the user's cart.
    # @return [Services::Result] An object indicating success/failure and relevant data/errors.
    def clear
      with_error_handling do
        @user.cart_items.destroy_all
        @user.reload
        return success_result(data: nil, message: 'Cart cleared successfully', status: :ok)
      end
    end

    # Retrieves the current state of the user's cart.
    #
    # @return [Hash] A hash containing cart items, total amount, and items count.
    def cart_summary
      cart_items = @user.cart_items.includes(:product)
      total_amount = @user.cart_items.sum('quantity * price_at_purchase')
      items_count = cart_items.sum(:quantity)
      {
        cart_items: cart_items,
        total_amount: total_amount,
        items_count: items_count
      }
    end
  end
end
