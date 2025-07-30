# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::PaymentCreationService, type: :service do
  let!(:user) { create(:user) }
  let!(:order) { create(:order, user: user) }
  let(:stripe_token) { 'tok_valid_token' }
  let(:payment_processor) { class_double(Services::PaymentProcessingService) }

  before do
    stub_const('Services::PaymentProcessingService', payment_processor)
    allow(payment_processor).to receive(:call).and_return(Services::Result.new(success?: true))
  end

  describe '.call' do
    context 'with valid parameters' do
      it 'calls the PaymentProcessingService with the correct arguments' do
        expect(payment_processor).to receive(:call).with(order: order, stripe_token: stripe_token)
        described_class.call(user: user, order_id: order.id, stripe_token: stripe_token)
      end

      it 'returns the result from the PaymentProcessingService' do
        success_result = Services::Result.new(success?: true, message: 'Processing complete')
        allow(payment_processor).to receive(:call).and_return(success_result)

        result = described_class.call(user: user, order_id: order.id, stripe_token: stripe_token)
        expect(result).to eq(success_result)
      end
    end

    context 'when the order is not found' do
      it 'returns a not_found failure result' do
        result = described_class.call(user: user, order_id: -1, stripe_token: stripe_token)

        expect(result.success?).to be false
        expect(result.status).to eq(:not_found)
        expect(result.errors).to include('Order not found or does not belong to the user.')
      end

      it 'does not call the PaymentProcessingService' do
        expect(payment_processor).not_to receive(:call)
        described_class.call(user: user, order_id: -1, stripe_token: stripe_token)
      end
    end

    context 'when the order does not belong to the user' do
      let!(:another_user) { create(:user) }
      let!(:another_order) { create(:order, user: another_user) }

      it 'returns a not_found failure result' do
        result = described_class.call(user: user, order_id: another_order.id, stripe_token: stripe_token)
        expect(result.success?).to be false
        expect(result.status).to eq(:not_found)
      end

      it 'does not call the PaymentProcessingService' do
        expect(payment_processor).not_to receive(:call)
        described_class.call(user: user, order_id: another_order.id, stripe_token: stripe_token)
      end
    end

    context 'when the order has already been paid for' do
      before do
        allow(order).to receive(:payment_status_paid?).and_return(true)
        allow(user.orders).to receive(:find_by).with(id: order.id).and_return(order)
      end

      it 'returns an unprocessable_entity failure result' do
        result = described_class.call(user: user, order_id: order.id, stripe_token: stripe_token)

        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_entity)
        expect(result.errors).to include('This order has already been paid for.')
      end

      it 'does not call the PaymentProcessingService' do
        expect(payment_processor).not_to receive(:call)
        described_class.call(user: user, order_id: order.id, stripe_token: stripe_token)
      end
    end
  end
end
