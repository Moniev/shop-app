# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles operations for Order resources via the API.
    #
    # This controller provides endpoints to manage user orders, including listing,
    # creating from a cart, viewing details, and modifying status.
    # It enforces authentication and role-based authorization for secure access.
    class OrdersController < ApplicationController
      load_and_authorize_resource except: %i[me create]

      # GET /api/v1/orders
      #
      # Retrieves a list of orders based on user role.
      #
      # Admins receive a list of all orders. Regular users receive a list
      # of their own orders only. The list is ordered by creation date.
      #
      # @return [void] Sets `@orders` for the Jbuilder view, implicitly rendering
      #   `index.json.jbuilder` with a status of `:ok` (200).
      def index
        @orders = Order.accessible_by(current_user).includes(:user, :items).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/orders/me
      #
      # Retrieves all orders for the currently authenticated user.
      #
      # A convenience endpoint for users to fetch their own order history.
      #
      # @return [void] Sets `@orders` for the Jbuilder view, implicitly rendering
      #   `me.json.jbuilder` with a status of `:ok` (200).
      def me
        @orders = current_user.orders.includes(:items).order(created_at: :desc)
        @status = :ok
      end

      # GET /api/v1/orders/:id
      #
      # Retrieves a single order by its ID.
      #
      # The `@order` instance variable is loaded and authorized automatically
      # by CanCanCan's `load_and_authorize_resource`.
      #
      # @return [void] Implicitly renders the `@order` using `show.json.jbuilder` with a
      #   status of `:ok` (200).
      def show
        @status = :ok
      end

      # POST /api/v1/orders
      #
      # Creates a new order from the items in the user's current cart.
      #
      # This action is transactional. It creates an `Order` record, assigns all
      # of the user's cart items to it, and clears the cart. No request body is needed.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `create.json.jbuilder` (or `show.json.jbuilder` if `create.json.jbuilder` is absent)
      #   with the appropriate status.
      # @see Services::OrderCreationService.call
      def create
        result = Services::OrderCreationService.call(current_user)
        @order = result.data[:order]
        bind_data(result)
      end

      # PATCH/PUT /api/v1/orders/:id
      #
      # Updates an existing order (Admin only).
      #
      # @param [Hash] :order The parameters for the order.
      # @option order [String] :status The new order status (e.g., "shipped").
      # @option order [String] :payment_status The new payment status (e.g., "paid").
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `update.json.jbuilder` (or `show.json.jbuilder` if `update.json.jbuilder` is absent)
      #   with the appropriate status.
      # @see Services::OrderManagementService#update
      def update
        result = order_management_service.update(order_params)
        @order = result.data[:order]
        bind_data(result)
      end

      # POST /api/v1/orders/:id/cancel
      #
      # Cancels an order.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `cancel.json.jbuilder` (or `show.json.jbuilder` if `cancel.json.jbuilder` is absent)
      #   with the appropriate status.
      # @see Services::OrderManagementService#cancel
      def cancel
        result = order_management_service.cancel
        @order = result.data[:order]
        bind_data(result)
      end

      # DELETE /api/v1/orders/:id
      #
      # Deletes an order permanently (Admin only).
      #
      # @return [void] Sets instance variables. For success (204 No Content), Rails
      #   will automatically set the status and return no content. For errors, it
      #   implicitly renders `destroy.json.jbuilder` (or `show.json.jbuilder`).
      # @see Services::OrderManagementService#destroy
      def destroy
        result = order_management_service.destroy
        bind_data(result)
      end

      private

      # Initializes and returns an instance of OrderManagementService for the loaded @order.
      # @return [Services::OrderManagementService] An instance of OrderManagementService.
      def order_management_service
        @order_management_service ||= Services::OrderManagementService.new(@order)
      end

      # Defines permitted parameters for updating an order.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def order_params
        params.require(:order).permit(:status, :payment_status)
      end
    end
  end
end
