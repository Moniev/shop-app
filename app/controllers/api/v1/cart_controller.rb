# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles shopping cart operations for the authenticated user.
    #
    # Provides endpoints for viewing, adding items to, removing items from, and
    # clearing the user's shopping cart. The cart is defined as a collection of `Item`
    # records associated with the current user that are not yet part of an `Order`.
    class CartController < Api::ApplicationController
      authorize_resource class: false

      # GET /api/v1/cart
      #
      # Displays the contents of the authenticated user's shopping cart.
      #
      # The cart includes a list of items, the total quantity of all items,
      # and the total calculated amount for the cart.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   a JSON object representing the cart, with a status of `:ok` (200).
      def show
        bind_data_and_render
      end

      # POST /api/v1/cart/add/:product_id
      #
      # Adds a product to the user's shopping cart.
      #
      # If the product is already in the cart, its quantity is increased. Otherwise,
      # a new item is created. Returns the updated state of the cart.
      #
      # @param [String] :product_id The UUID of the product to add.
      # @param [Integer] :quantity The quantity to add (must be > 0).
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   the updated cart with an appropriate HTTP status.
      # @see Services::CartService#add_product
      def add
        result = cart_service.add_product(params[:product_id], add_params[:quantity])
        bind_data_and_render(result)
      end

      # DELETE /api/v1/cart/revoke/:item_id
      #
      # Removes an item from the user's shopping cart.
      #
      # This can be used to completely remove an item or reduce its quantity.
      # If `quantity_to_remove` is not provided, the entire item is deleted.
      # Returns the updated state of the cart.
      #
      # @param [String] :item_id The ID of the cart item to remove/modify.
      # @param [Integer] :quantity_to_remove (Optional) The quantity to remove.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   the updated cart with an appropriate HTTP status.
      # @see Services::CartService#remove_product
      def revoke
        result = cart_service.remove_product(params[:item_id], revoke_params[:quantity_to_remove])
        bind_data_and_render(result)
      end

      # DELETE /api/v1/cart/clear
      #
      # Clears all items from the user's shopping cart.
      #
      # @return [void] Sets instance variables for the Jbuilder view to render
      #   the empty cart with an appropriate HTTP status.
      # @see Services::CartService#clear
      def clear
        result = cart_service.clear
        bind_data_and_render(result)
      end

      private

      # Initializes and returns an instance of CartService for the current user.
      # @return [Services::CartService] An instance of CartService.
      def cart_service
        @cart_service ||= Services::CartService.new(current_user)
      end

      def bind_data_and_render(result = nil)
        if result
          bind_data(result)
        else
          @status = :ok
          @errors = []
        end
        summary = cart_service.get_cart_summary
        @cart_items = summary[:cart_items]
        @total_amount = summary[:total_amount]
        @items_count = summary[:items_count]

        render :show, status: @status, locals: { current_user: current_user }
      end

      # Strong parameters for the 'add' action.
      #
      # @return [ActionController::Parameters] Permitted parameters.
      def add_params
        params.permit(:quantity)
      end

      # Strong parameters for the 'revoke' action.
      #
      # @return [ActionController::Parameters] Permitted parameters.
      def revoke_params
        params.permit(:quantity_to_remove)
      end
    end
  end
end
