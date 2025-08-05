# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Stripe Webhooks', type: :request do
  path '/api/v1/stripe_payments_webhook/handle' do
    post 'Handles Stripe webhook events' do
      tags 'Stripe Webhooks'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: { type: :object }

      parameter name: 'Stripe-Signature', in: :header, type: :string

      response '200', 'webhook acknowledged' do
        let(:payload) { { id: 'evt_123', type: 'charge.succeeded' }.to_json }
        let(:'Stripe-Signature') { 't=123,v1=abc' }

        before do
          successful_result = Services::Result.new(success?: true, message: 'Webhook processed', status: :ok)
          allow(Services::StripeWebhookHandlerService).to receive(:call).and_return(successful_result)
        end

        run_test!
      end

      response '400', 'bad request (e.g., invalid signature)' do
        let(:payload) { {}.to_json }
        let(:'Stripe-Signature') { 'invalid_signature' }

        before do
          bad_request_result = Services::Result.new(success?: false, errors: ['Invalid signature'],
                                                    status: :bad_request)
          allow(Services::StripeWebhookHandlerService).to receive(:call).and_return(bad_request_result)
        end

        run_test!
      end

      response '422', 'processing error' do
        let(:payload) { { id: 'evt_123', type: 'charge.succeeded' }.to_json }
        let(:'Stripe-Signature') { 't=123,v1=abc' }

        before do
          error_result = Services::Result.new(success?: false, errors: ['Order not found'],
                                              status: :unprocessable_content)
          allow(Services::StripeWebhookHandlerService).to receive(:call).and_return(error_result)
        end

        run_test!
      end
    end
  end
end
