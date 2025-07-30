# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::OrderManagementService, type: :service do
  before do
    allow_any_instance_of(CartObserver).to receive(:after_create)
  end

  let!(:order) { create(:order, :with_items) }
  let(:service) { described_class.new(order) }

  describe '#update' do
    context 'with valid parameters' do
      it 'updates the order and returns a successful result' do
        result = service.update({ delivery_address: 'New Address 123' })

        expect(result.success?).to be true
        expect(order.reload.delivery_address).to eq('New Address 123')
        expect(result.status).to eq(:ok)
      end
    end

    context 'with invalid parameters' do
      it 'does not update the order and returns a failure result' do
        result = service.update({ status: nil })

        expect(result.success?).to be false
        expect(result.errors).to include("Status can't be blank")
        expect(result.status).to eq(:unprocessable_entity)
      end
    end
  end

  describe '#cancel' do
    context 'when the order has a cancellable status (e.g., pending)' do
      it 'cancels the order successfully' do
        order.update!(status: :pending)
        result = service.cancel

        expect(result.success?).to be true
        expect(order.reload.status_cancelled?).to be true
      end
    end

    context 'when the order has a non-cancellable status (e.g., shipped)' do
      it 'returns a failure result and does not cancel the order' do
        order.update!(status: :shipped)
        result = service.cancel

        expect(result.success?).to be false
        expect(result.errors.first).to include('Cannot cancel order with status: shipped')
        expect(order.reload.status_shipped?).to be true
      end
    end
  end

  describe '#mark_as_paid' do
    it 'updates payment_status to paid' do
      service.mark_as_paid
      expect(order.reload.payment_status_paid?).to be true
    end
  end

  describe '#mark_as_shipped' do
    it 'updates status to shipped' do
      service.mark_as_shipped
      expect(order.reload.status_shipped?).to be true
    end
  end

  describe '#add_product' do
    let(:new_product) { create(:product, price: 50) }

    context 'with valid input' do
      it 'adds a new product to the order' do
        new_product = create(:product, price: 50)
        result = service.add_product(new_product, 2)
        order.reload
        expect(result.success?).to be true

        expected_total = order.items.sum { |item| item.price_at_purchase * item.quantity }
        expect(order.total_amount).to be_within(0.01).of(expected_total)
      end

      it 'increases the quantity of an existing product' do
        existing_item = order.items.first
        initial_quantity = existing_item.quantity

        result = service.add_product(existing_item.product, 3)

        expect(result.success?).to be true
        expect(existing_item.reload.quantity).to eq(initial_quantity + 3)
      end
    end

    context 'with invalid input' do
      it 'returns a failure result for zero quantity' do
        result = service.add_product(new_product, 0)
        expect(result.success?).to be false
        expect(result.errors).to include('Invalid product or quantity.')
      end

      it 'returns a failure result for a nil product' do
        result = service.add_product(nil, 1)
        expect(result.success?).to be false
        expect(result.errors).to include('Invalid product or quantity.')
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs the error and returns an internal_server_error result' do
        allow(order).to receive(:save!).and_raise(StandardError, 'DB error')
        allow(Rails.logger).to receive(:error)

        result = service.add_product(new_product, 1)

        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(Rails.logger).to have_received(:error)
      end
    end
  end
end
