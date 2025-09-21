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
    include Concerns::ResultHelpers
    include Concerns::Handlers

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
      if cart_items.empty?
        return unprocessable_content_with_errors_result(errors: ['Your cart is empty or no items were selected.'],
                                                        message: 'Your cart is empty or no items were selected.')
      end

      user_location = find_user_location
      process_order_creation(cart_items, user_location)
    end

    private

    def process_order_creation(cart_items, user_location)
      with_error_handling do
        order = nil
        ActiveRecord::Base.transaction do
          order = build_order(cart_items, user_location)
        end
        success_result(data: { order: order }, message: 'Order created successfully', status: :created)
      end
    end

    def build_order(cart_items, user_location)
      order_location = create_location_snapshot(user_location)
      order = @user.orders.build(
        package_carrier: @package_carrier,
        location: order_location
      )

      order.items = cart_items
      order.save!
      Item.where(id: order.item_ids).update_all(user_id: nil)
      order
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

    def find_user_location
      @user.user_detail&.locations&.find_by(id: @location_id)
    end
  end
end
