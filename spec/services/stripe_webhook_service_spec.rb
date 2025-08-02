# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::StripeWebhookService, type: :service do
  let!(:order) { create(:order) }
  let!(:payment) { create(:payment, order: order, stripe_charge_id: 'ch_123') }
  let(:charge_object) { OpenStruct.new(id: payment.stripe_charge_id) }

  describe '.handle' do
    context 'with a "charge.succeeded" event' do
      let(:event) { OpenStruct.new(type: 'charge.succeeded', data: OpenStruct.new(object: charge_object)) }

      it 'updates the payment status to completed' do
        described_class.handle(event)
        expect(payment.reload.status).to eq('completed')
      end

      it 'marks the associated order as paid' do
        described_class.handle(event)
        expect(order.reload.payment_status).to eq('paid')
      end

      it 'returns a successful result' do
        result = described_class.handle(event)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
      end

      context 'when the payment is already completed' do
        before { payment.update!(status: :completed) }

        it 'does not try to update the payment again' do
          expect(payment).not_to receive(:mark_as_completed!)
          described_class.handle(event)
        end
      end
    end

    context 'with a "charge.failed" event' do
      let(:charge_object) { OpenStruct.new(id: payment.stripe_charge_id, failure_message: 'Your card was declined.') }
      let(:event) { OpenStruct.new(type: 'charge.failed', data: OpenStruct.new(object: charge_object)) }

      it 'updates the payment status to failed' do
        described_class.handle(event)
        expect(payment.reload.status).to eq('failed')
        expect(payment.reload.error_message).to eq('Your card was declined.')
      end

      it 'updates the order payment status to failed' do
        described_class.handle(event)
        expect(order.reload.payment_status).to eq('failed')
      end
    end

    context 'with a "charge.refunded" event' do
      let(:event) { OpenStruct.new(type: 'charge.refunded', data: OpenStruct.new(object: charge_object)) }
      before { payment.update!(status: :completed) }

      it 'updates the payment status to refunded' do
        described_class.handle(event)
        expect(payment.reload.status).to eq('refunded')
      end

      it 'updates the order status and payment status to refunded' do
        described_class.handle(event)
        order.reload
        expect(order.status).to eq('refunded')
        expect(order.payment_status).to eq('refunded')
      end
    end

    context 'with an unhandled event type' do
      let(:event) { OpenStruct.new(type: 'customer.subscription.created', data: OpenStruct.new(object: {})) }

      it 'logs a warning' do
        allow(Rails.logger).to receive(:warn)
        expect(Rails.logger).to receive(:warn).with(/Unhandled Stripe event type/)
        described_class.handle(event)
      end

      it 'returns a successful result' do
        result = described_class.handle(event)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
      end
    end

    context 'when an unexpected error occurs' do
      let(:event) { OpenStruct.new(type: 'charge.succeeded', data: OpenStruct.new(object: charge_object)) }

      before do
        allow(Payment).to receive(:find_by).and_raise(StandardError, 'Database is down')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error processing Stripe event/)
        described_class.handle(event)
      end

      it 'returns an internal_server_error failure result' do
        result = described_class.handle(event)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end
