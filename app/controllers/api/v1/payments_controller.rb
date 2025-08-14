# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles operations for Payment resources via the API.
    #
    # This controller provides endpoints to create and view payments associated with orders.
    # It integrates with the Payment model, which handles interaction with the
    # Stripe payment gateway. Access is restricted based on user ownership and roles.
    class PaymentsController < Api::ApplicationController
      load_and_authorize_resource except: [:create]

      # GET /api/v1/payments
      #
      # Retrieves a list of all payments (Admin only).
      #
      # This endpoint is restricted to admin users and returns a comprehensive list
      # of all payment transactions in the system, ordered by creation date.
      #
      # @return [void] Sets `@payments` for the Jbuilder view, implicitly rendering
      #   `index.json.jbuilder` with a status of `:ok` (200).
      def index
        @payments = Payment.includes(:order).order(created_at: :desc)
        bind_data_and_render(nil, 'index')
      end

      # GET /api/v1/payments/:id
      #
      # Retrieves a single payment by its ID.
      #
      # The `@payment` instance variable is loaded and authorized automatically
      # by CanCanCan's `load_and_authorize_resource`. Accessible only to the
      # user who owns the associated order or to an admin.
      #
      # @return [void] Implicitly renders the `@payment` using `show.json.jbuilder` with a
      #   status of `:ok` (200).
      def show
        bind_data_and_render(nil, 'show')
      end

      # POST /api/v1/payments
      #
      # Creates a new payment for a specific order using a Stripe token.
      #
      # @param [Hash] :payment The parameters for the payment.
      # @option payment [Integer] :order_id The ID of the order to be paid.
      # @option payment [String] :stripe_token The single-use token from Stripe.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `create.json.jbuilder` (or `show.json.jbuilder` if absent) with the appropriate status.
      # @see Services::PaymentCreationService.call
      def create
        result = Services::PaymentCreationService.call(
          user: current_user,
          order_id: payment_params[:order_id],
          stripe_token: payment_params[:stripe_token]
        )

        bind_data_and_render(result, 'show')
      end

      private

      def bind_data_and_render(result = nil, view_name = 'show')
        if result
          @success = result.success?
          @status = result.status
          @message = result.message || ''

          if @success
            @payment = result.data[:payment] if result.data.key?(:payment)
            @payments = result.data[:payments] if result.data.key?(:payments)
            render view_name, status: @status
          else
            render json: { errors: result.errors || [] }, status: @status
          end
        else
          render view_name, status: :ok
        end
      end

      # Defines permitted parameters for creating a payment.
      #
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def payment_params
        params.require(:payment).permit(:order_id, :stripe_token)
      end
    end
  end
end
