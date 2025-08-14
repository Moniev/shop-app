# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles operations for Order resources via the API.
    #
    # This controller provides endpoints to manage user orders, including listing,
    # creating from a cart, viewing details, and modifying status.
    # It enforces authentication and role-based authorization for secure access.
    class OrdersController < Api::ApplicationController
      before_action :set_order, only: %i[add_product remove_product mark_order_status mark_payment_status cancel]
      before_action :set_product, only: %i[add_product remove_product]
      load_and_authorize_resource except: %i[me create add_product remove_product cancel mark_order_status
                                             mark_payment_status]

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
        @orders = Order.accessible_by(current_ability).includes(:user, :items).order(created_at: :desc)
        bind_data_and_render(nil, 'index')
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
        bind_data_and_render(nil, 'index')
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
        bind_data_and_render(nil, 'show')
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
        result = Services::OrderCreationService.call(
          user: current_user,
          cart_item_ids: order_params[:cart_item_ids]
        )
        bind_data_and_render(result, 'show')
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
        result = order_management_service.update(update_order_params)
        bind_data_and_render(result, 'show')
      end

      def add_product
        quantity = add_product_params[:quantity].to_i
        result = order_management_service.add_product(@product, quantity)
        bind_data_and_render(result, 'show')
      end

      def remove_product
        quantity = remove_product_params[:quantity]
        result = order_management_service.remove_product(@product, quantity)
        bind_data_and_render(result, 'show')
      end

      def mark_order_status
        result = order_management_service.mark_order_status(order_status_params[:status])
        bind_data_and_render(result, 'show')
      end

      def mark_payment_status
        result = order_management_service.mark_payment_status(payment_status_params[:payment_status])
        bind_data_and_render(result, 'show')
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
        bind_data_and_render(result, 'show')
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
        handle_destroy_response(result)
      end

      private

      def set_order
        @order = Order.find_by(id: params[:id])
        unless @order
          render json: { errors: ['Order not found.'] }, status: :not_found
          return
        end
        authorize! action_name.to_sym, @order
      end

      def set_product
        product_id = params[:product_id] || add_product_params[:product_id]
        @product = Product.find_by(id: product_id)
        render json: { errors: ['Product not found.'] }, status: :not_found unless @product
        @product
      end

      def bind_data_and_render(result = nil, view_name = 'show')
        if result
          bind_data(result)
          if @success
            @order = @data[:order] if @data.key?(:order)
            @orders = @data[:orders] if @data.key?(:orders)

            render view_name, status: @status
          else
            render json: { errors: @errors }, status: @status
          end
        else
          render view_name, status: :ok
        end
      end

      def handle_destroy_response(result)
        bind_data(result)
        if @success
          head @status
        else
          render json: { errors: @errors }, status: @status
        end
      end

      # Initializes and returns an instance of OrderManagementService for the loaded @order.
      # @return [Services::OrderManagementService] An instance of OrderManagementService.
      def order_management_service
        @order_management_service ||= Services::OrderManagementService.new(@order)
      end

      def update_order_params
        params.require(:order).permit(:status, :payment_status)
      end

      # Defines permitted parameters for updating an order.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def order_params
        params.fetch(:order, {}).permit(cart_item_ids: [])
      end

      def add_product_params
        params.require(:order).permit(:product_id, :quantity)
      end

      def remove_product_params
        params.permit(:product_id, :quantity)
      end

      def order_status_params
        params.require(:order).permit(:status)
      end

      def payment_status_params
        params.require(:order).permit(:payment_status)
      end
    end
  end
end
