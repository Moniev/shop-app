# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::OrderCreationService, type: :service do
  describe '.call' do
    let!(:user) { create(:user) }
    let(:product) { create(:product) }

    context 'when the user has an empty cart' do
      it 'returns a failure result and does not create an order' do
        expect { described_class.call(user) }.not_to change(Order, :count)

        result = described_class.call(user)

        expect(result.success?).to be false
        expect(result.errors).to include('Your cart is empty.')
        expect(result.status).to eq(:unprocessable_entity)
      end
    end

    context 'when the user has items in the cart' do
      let!(:cart_item) { create(:item, :in_cart, user: user, product: product, quantity: 2) }

      it 'creates an order, returns a success result, and moves cart items' do
        result = nil

        expect do
          result = described_class.call(user)
        end.to change(Order, :count).by(1)

        expect(result.success?).to be true
        expect(result.data[:order]).to be_a(Order)
        expect(result.status).to eq(:created)

        expect(user.reload.cart_items).to be_empty
      end

      it 'moves items from the cart to the new order' do
        result = described_class.call(user)
        order = result.data[:order]

        expect(user.reload.cart_items).to be_empty
        expect(order.items.count).to eq(1)
        expect(order.items.first.product).to eq(product)
      end
    end

    context 'when order creation fails due to a validation error' do
      let!(:cart_item) { create(:item, :in_cart, user: user, product: product) }

      before do
        allow(user.orders).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'does not create an order and leaves items in the cart' do
        expect { described_class.call(user) }.not_to change(Order, :count)
        expect(user.reload.cart_items.count).to eq(1)
      end

      it 'returns a failure result with validation errors' do
        result = described_class.call(user)

        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_entity)
        expect(result.message).to include('validation errors')
      end
    end

    context 'when an unexpected standard error occurs' do
      let!(:cart_item) { create(:item, :in_cart, user: user, product: product) }
      let(:error_message) { 'Something went wrong on the database level' }

      before do
        allow_any_instance_of(ActiveRecord::Relation).to receive(:update_all).and_raise(StandardError, error_message)
        allow(Rails.logger).to receive(:error)
      end

      it 'does not create an order' do
        expect { described_class.call(user) }.not_to change(Order, :count)
      end

      it 'logs the error' do
        described_class.call(user)
        expect(Rails.logger).to have_received(:error).with(/Order creation failed for user #{user.id}: #{error_message}/)
      end

      it 'returns an internal server error result' do
        result = described_class.call(user)

        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(result.errors).to include('An unexpected error occurred during order creation.')
      end
    end
  end
end
