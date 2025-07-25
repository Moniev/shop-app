require 'swagger_helper'

RSpec.describe 'API V1 Cart', type: :request do
  let(:test_user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_jwt_for(test_user)}" }

  path '/api/v1/cart' do
    get("Shows the current user's cart") do
      tags 'Cart'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/Cart'
        run_test!
      end

      response(401, 'unauthorized') do
        run_test!
      end
    end
  end

  path '/api/v1/cart/add/{product_id}' do
    post('Adds an item to the cart') do
      tags 'Cart'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :product_id, in: :path, type: :string, format: :uuid, required: true,
                description: 'ID of the product to add'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          quantity: { type: :integer, example: 1, description: 'Quantity to add' }
        },
        required: ['quantity']
      }

      response(200, 'product added successfully') do
        schema '$ref' => '#/components/schemas/Cart'
        let(:product_id) { 'some-uuid' }
        let(:params) { { quantity: 1 } }
        run_test!
      end

      response(404, 'product not found') do
        run_test!
      end
    end
  end

  path '/api/v1/cart/revoke/{item_id}' do
    delete('Removes an item from the cart') do
      tags 'Cart'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :item_id, in: :path, type: :string, required: true, description: 'ID of the cart item to remove'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          quantity_to_remove: { type: :integer, example: 1,
                                description: 'Optional quantity to remove. If absent, the whole item is removed.' }
        }
      }

      response(200, 'item removed or quantity reduced') do
        schema '$ref' => '#/components/schemas/Cart'
        let(:item_id) { 'some-id' }
        let(:params) { { quantity_to_remove: 1 } }
        run_test!
      end

      response(404, 'item not found in cart') do
        run_test!
      end
    end
  end

  path '/api/v1/cart/clear' do
    delete('Clears all items from the cart') do
      tags 'Cart'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'cart cleared successfully') do
        schema '$ref' => '#/components/schemas/Cart'
        run_test!
      end
    end
  end
end
