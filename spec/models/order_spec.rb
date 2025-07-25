# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order, type: :model do
  describe '.create_from_cart_for' do
    let(:user) { create(:user) }
    let(:product) { create(:product, price: 100) }

    context "when the user's cart is not empty" do
      before do
        create(:item, user: user, product: product, quantity: 2, order: nil)
      end

      it 'creates a new order' do
        expect { Order.create_from_cart_for(user) }.to change(Order, :count).by(1)
      end

      it 'assigns items from the cart to the new order' do
        result = Order.create_from_cart_for(user)
        order = result[:order]
        expect(user.cart_items.count).to eq(0)
        expect(order.items.count).to eq(1)
      end

      it 'correctly calculates the total amount of the order' do
        result = Order.create_from_cart_for(user)
        order = result[:order]
        expect(order.total_amount).to eq(200)
      end
    end

    context "when the user's cart is empty" do
      it 'returns an error' do
        result = Order.create_from_cart_for(user)
        expect(result[:errors]).to include('Your cart is empty')
      end
    end
  end
end
