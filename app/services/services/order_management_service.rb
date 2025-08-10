# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class OrderManagementService
    def initialize(order)
      @order = order
    end

    def update(params)
      if @order.update(params)
        Services::Result.new(success?: true, data: { order: @order }, status: :ok,
                             message: 'Order updated successfully.')
      else
        Services::Result.new(success?: false, errors: @order.errors.full_messages, status: :unprocessable_content,
                             message: 'Order update failed due to validation errors.')
      end
    rescue StandardError => e
      Rails.logger.error("Order update failed for order ID #{@order.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during order update.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def cancel
      unless @order.status_pending? || @order.status_processing?
        return Services::Result.new(
          success?: false,
          errors: ["Cannot cancel order with status: #{@order.status}"],
          status: :unprocessable_content,
          message: "Cannot cancel order with status: #{@order.status}."
        )
      end

      if @order.update(status: :cancelled)
        Services::Result.new(success?: true, data: { order: @order }, status: :ok,
                             message: 'Order cancelled successfully.')
      else
        Services::Result.new(success?: false, errors: @order.errors.full_messages, status: :unprocessable_content,
                             message: 'Order cancellation failed due to validation errors.')
      end
    rescue StandardError => e
      Rails.logger.error("Order cancellation failed for order ID #{@order.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during order cancellation.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def destroy
      @order.destroy
      Services::Result.new(success?: true, status: :no_content)
    rescue StandardError => e
      Rails.logger.error("Failed to destroy order ID #{@order.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred while destroying the order.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def add_product(product, quantity)
      unless product && quantity.to_i.positive?
        return Services::Result.new(success?: false, errors: ['Invalid product or quantity.'],
                                    status: :unprocessable_content, message: 'Failed to add product: invalid input.')
      end

      ActiveRecord::Base.transaction do
        item = @order.items.find_or_initialize_by(product_id: product.id)
        item.price_at_purchase ||= product.price
        item.increment!(:quantity, quantity.to_i)

        @order.save!
      end

      Services::Result.new(success?: true, data: { order: @order }, status: :ok,
                           message: 'Product added to order successfully.')
    rescue ActiveRecord::RecordInvalid => e
      Services::Result.new(success?: false, errors: e.record.errors.full_messages, status: :unprocessable_content,
                           message: 'Failed to add product to order due to validation errors.')
    rescue StandardError => e
      Rails.logger.error("Failed to add product to order ID #{@order.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred while adding product to order.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def remove_product(product, quantity = nil)
      item = @order.items.find_by(product_id: product&.id)

      unless item
        return Services::Result.new(success?: false, errors: ['Product not found in order.'],
                                    status: :not_found, message: 'Failed to remove product: product not found.')
      end

      ActiveRecord::Base.transaction do
        if quantity.nil?
          item.destroy!
        else
          quantity_to_remove = quantity.to_i
          if quantity_to_remove <= 0
            return Services::Result.new(success?: false, errors: ['Quantity must be a positive number.'],
                                        status: :unprocessable_content, message: 'Invalid quantity.')
          end
          if quantity_to_remove > item.quantity
            return Services::Result.new(success?: false, errors: ["Cannot remove #{quantity_to_remove} items, only #{item.quantity} present."],
                                        status: :unprocessable_content, message: 'Quantity to remove exceeds quantity in order.')
          end

          item.decrement!(:quantity, quantity_to_remove)
          item.destroy! if item.quantity <= 0
        end
        @order.items.reload
        @order.save!
      end

      Services::Result.new(success?: true, data: { order: @order.reload }, status: :ok,
                           message: 'Product removed from order successfully.')
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
      Services::Result.new(success?: false, errors: e.record.errors.full_messages, status: :unprocessable_content,
                           message: 'Failed to remove product from order due to validation errors.')
    rescue StandardError => e
      Rails.logger.error("Failed to remove product from order ID #{@order.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred while removing product from order.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def mark_order_status(status)
      mark_status(:status, status, Order.statuses)
    end

    def mark_payment_status(status)
      mark_status(:payment_status, status, Order.payment_statuses)
    end

    def mark_status(attribute, status, valid_statuses)
      status_key = status.to_s
      unless valid_statuses.key?(status_key)
        return Services::Result.new(
          success?: false,
          errors: ["'#{status_key}' is not a valid #{attribute}."],
          status: :unprocessable_content,
          message: 'Invalid status provided.'
        )
      end

      if @order.update(attribute => status_key)
        Services::Result.new(
          success?: true,
          data: { order: @order },
          status: :ok,
          message: "Order #{attribute} successfully updated to '#{status_key}'."
        )
      else
        Services::Result.new(
          success?: false,
          errors: @order.errors.full_messages,
          status: :unprocessable_content,
          message: "Failed to update order #{attribute}."
        )
      end
    rescue StandardError => e
      Rails.logger.error("Failed to update #{attribute} for order #{@order.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ["An unexpected error occurred while updating the order #{attribute}."],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
