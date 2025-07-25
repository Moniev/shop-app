require 'swagger_helper'

RSpec.describe 'API V1 Orders', type: :request do
  let(:test_user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_jwt_for(test_user)}" }

  path '/api/v1/orders' do
    get('Lists orders') do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/Order' }
        run_test!
      end

      response(401, 'unauthorized') do
        run_test!
      end
    end

    post('Creates an order from the cart') do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]

      response(201, 'order created') do
        schema '$ref' => '#/components/schemas/Order'
        run_test!
      end

      response(422, 'unprocessable entity (e.g., empty cart)') do
        schema type: :object, properties: {
          errors: { type: :array, items: { type: :string }, example: ['Your cart is empty.'] }
        }
        run_test!
      end
    end
  end

  path '/api/v1/orders/me' do
    get('Lists orders for the current user') do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/Order' }
        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'Order ID'

    get('Shows a single order') do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/Order'
        let(:id) { '123' }
        run_test!
      end

      response(404, 'not found') do
        run_test!
      end
    end

    patch('Updates an order (Admin only)') do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :order_params, in: :body, schema: {
        type: :object,
        properties: {
          order: {
            type: :object,
            properties: {
              status: { type: :string, example: 'shipped' },
              payment_status: { type: :string, example: 'paid' }
            }
          }
        },
        required: ['order']
      }

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/Order'
        let(:id) { '123' }
        let(:order_params) { { order: { status: 'shipped' } } }
        run_test!
      end

      response(403, 'forbidden') do
        run_test!
      end
    end

    delete('Deletes an order (Admin only)') do
      tags 'Orders'
      security [Bearer: []]

      response(204, 'no content') do
        let(:id) { '123' }
        run_test!
      end

      response(403, 'forbidden') do
        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}/cancel' do
    post('Cancels an order') do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, description: 'Order ID'

      response(200, 'successful') do
        schema type: :object, properties: {
          message: { type: :string, example: 'Order has been cancelled.' }
        }
        let(:id) { '123' }
        run_test!
      end

      response(422, 'unprocessable entity (e.g., order cannot be cancelled)') do
        schema type: :object, properties: {
          errors: { type: :array, items: { type: :string }, example: ['Order cannot be cancelled at this stage.'] }
        }
        let(:id) { '123' }
        run_test!
      end
    end
  end
end
