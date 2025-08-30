# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class OrderCreationService
    def self.call(user:, package_carrier:, location_id:, cart_item_ids: [])
      new(user: user, package_carrier: package_carrier, location_id: location_id, cart_item_ids: cart_item_ids).call
    end

    def initialize(user:, package_carrier:, location_id:, cart_item_ids: [])
      @user = user
      @location_id = location_id
      @cart_item_ids = cart_item_ids
      @package_carrier = package_carrier
    end

    def call
      cart_items = find_cart_items
      return handle_empty_cart if cart_items.empty?

      user_location = find_user_location
      process_order_creation(cart_items, user_location)
    end

    private

    def process_order_creation(cart_items, user_location)
      order = nil
      ActiveRecord::Base.transaction do
        order_location = create_location_snapshot(user_location)
        order = @user.orders.build(
          package_carrier: @package_carrier,
          location: order_location
        )

        order.items = cart_items
        order.save!
        Item.where(id: order.item_ids).update_all(user_id: nil)
      end

      Services::Result.new(
        success?: true,
        data: { order: order },
        status: :created,
        message: 'Order created successfully.'
      )
    rescue ActiveRecord::RecordInvalid => e
      handle_validation_error(e, order)
    rescue StandardError => e
      handle_generic_error(e)
    end

    def create_location_snapshot(user_location)
      new_location = user_location.dup
      new_location.user_detail_id = nil
      new_location.save!
      new_location
    end

    def find_cart_items
      if @cart_item_ids.present?
        @user.cart_items.where(id: @cart_item_ids)
      else
        @user.cart_items
      end
    end

    def handle_empty_cart
      Services::Result.new(
        success?: false,
        errors: ['Your cart is empty or no items were selected.'],
        status: :unprocessable_content
      )
    end

    def find_user_location
      @user.user_detail&.locations&.find_by(id: @location_id)
    end

    def handle_invalid_location
      Services::Result.new(
        success?: false,
        errors: ['Invalid shipping address selected.'],
        status: :not_found
      )
    end

    def handle_validation_error(exception, order)
      errors = order&.errors&.full_messages || exception.message.split("\n")
      Services::Result.new(
        success?: false,
        errors: errors,
        status: :unprocessable_content,
        message: 'Order creation failed due to validation errors.'
      )
    end

    def handle_generic_error(exception)
      Rails.logger.error("Order creation failed for user #{@user.id}: #{exception.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during order creation.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
