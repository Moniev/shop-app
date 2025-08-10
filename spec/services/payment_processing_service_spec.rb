# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::PaymentProcessingService, type: :service do
  before do
    allow_any_instance_of(CartObserver).to receive(:after_create)
  end

  let!(:user) { create(:user, mail: 'customer@example.com') }
  let!(:order) { create(:order, :with_items, user: user) }
  let(:stripe_token) { 'tok_visa' }
  let(:stripe_charge) { class_double(Stripe::Charge) }

  before do
    stub_const('Stripe::Charge', stripe_charge)
    allow(order).to receive(:mark_as_paid!)
    order.reload
    order.save!
  end

  describe '.call' do
    context 'when payment processing is successful' do
      let(:successful_charge) do
        instance_double(
          Stripe::Charge,
          id: 'ch_12345',
          currency: 'pln'
        )
      end

      before do
        allow(stripe_charge).to receive(:create).and_return(successful_charge)
      end

      it 'creates a new Payment record' do
        expect do
          described_class.call(order: order, stripe_token: stripe_token)
        end.to change(Payment, :count).by(1)
      end

      it 'updates the payment status to paid' do
        described_class.call(order: order, stripe_token: stripe_token)
        expect(Payment.last.status).to eq('paid')
      end

      it 'updates the order status by calling mark_as_paid!' do
        expect(order).to receive(:mark_as_paid!)
        described_class.call(order: order, stripe_token: stripe_token)
      end

      it 'returns a successful result' do
        result = described_class.call(order: order, stripe_token: stripe_token)
        expect(result.success?).to be true
        expect(result.status).to eq(:created)
        expect(result.data[:payment]).to be_a(Payment)
      end
    end

    context 'when the initial payment object is invalid' do
      before do
        allow(order).to receive(:total_amount).and_return(-100)
      end

      it 'does not create a Payment record' do
        expect do
          described_class.call(order: order, stripe_token: stripe_token)
        end.not_to change(Payment, :count)
      end

      it 'does not call the Stripe API' do
        expect(stripe_charge).not_to receive(:create)
        described_class.call(order: order, stripe_token: stripe_token)
      end

      it 'returns an unprocessable_content failure result' do
        result = described_class.call(order: order, stripe_token: stripe_token)
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Amount must be greater than 0')
      end
    end

    context 'when Stripe returns a card error' do
      let(:card_error_json) { { error: { message: 'Your card was declined.' } } }

      before do
        allow(stripe_charge).to receive(:create).and_raise(Stripe::CardError.new('Card Declined', 'param',
                                                                                 json_body: card_error_json))
      end

      it 'creates a payment record with a failed status' do
        described_class.call(order: order, stripe_token: stripe_token)
        expect(Payment.last.status).to eq('failed')
        expect(Payment.last.error_message).to eq('Your card was declined.')
      end

      it 'does not mark the order as paid' do
        expect(order).not_to receive(:mark_as_paid!)
        described_class.call(order: order, stripe_token: stripe_token)
      end

      it 'returns a failure result with the card error message' do
        result = described_class.call(order: order, stripe_token: stripe_token)
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Your card was declined.')
      end
    end

    context 'when Stripe returns a generic API error' do
      before do
        allow(stripe_charge).to receive(:create).and_raise(Stripe::StripeError.new('API connection error'))
      end

      it 'creates a payment record with a failed status' do
        described_class.call(order: order, stripe_token: stripe_token)
        expect(Payment.last.status).to eq('failed')
        expect(Payment.last.error_message).to eq('API connection error')
      end

      it 'returns an internal_server_error failure result' do
        result = described_class.call(order: order, stripe_token: stripe_token)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end
