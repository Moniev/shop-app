# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Payments', type: :request do
  let(:test_user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_jwt_for(test_user)}" }

  path '/api/v1/payments' do
    get('Lists all payments (Admin only)') do
      tags 'Payments'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/Payment' }
        run_test!
      end

      response(401, 'unauthorized') do
        run_test!
      end

      response(403, 'forbidden') do
        run_test!
      end
    end

    post('Creates a new payment') do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :payment_params, in: :body, schema: {
        type: :object,
        properties: {
          payment: {
            type: :object,
            properties: {
              order_id: { type: :integer, example: 1 },
              stripe_token: { type: :string, example: 'tok_visa' }
            },
            required: %w[order_id stripe_token]
          }
        },
        required: ['payment']
      }

      response(201, 'payment created') do
        schema '$ref' => '#/components/schemas/Payment'
        let(:payment_params) { { payment: { order_id: 1, stripe_token: 'tok_visa' } } }
        run_test!
      end

      response(404, 'order not found') do
        let(:payment_params) { { payment: { order_id: 999, stripe_token: 'tok_visa' } } }
        run_test!
      end

      response(422, 'unprocessable entity (e.g., order already paid)') do
        let(:payment_params) { { payment: { order_id: 1, stripe_token: 'tok_visa' } } }
        run_test!
      end
    end
  end

  path '/api/v1/payments/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'Payment ID'

    get('Shows a single payment') do
      tags 'Payments'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/Payment'
        let(:id) { '123' }
        run_test!
      end

      response(404, 'not found') do
        run_test!
      end
    end
  end
end
