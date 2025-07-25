# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Products', type: :request do
  let(:test_user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_jwt_for(test_user)}" }

  let(:product_schema) do
    {
      type: :object,
      properties: {
        id: { type: :string, format: :uuid },
        name: { type: :string, example: 'Classic T-Shirt' },
        price: { type: :string, format: :decimal },
        description: { type: :string, nullable: true },
        created_at: { type: :string, format: 'date-time' },
        product_photos: {
          type: :array,
          items: {
            type: :object,
            properties: { id: { type: :integer }, url: { type: :string } }
          }
        }
      },
      required: %w[id name price]
    }
  end

  path '/api/v1/products' do
    get('Lists all products') do
      tags 'Products'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, description: 'Page number for pagination', required: false

      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/Product' }
        run_test!
      end
    end

    post('Creates a new product') do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :product_params, in: :body, schema: {
        type: :object,
        properties: {
          product: {
            type: :object,
            properties: {
              name: { type: :string, example: 'New Gadget' },
              price: { type: :number, example: 99.99 },
              description: { type: :string, example: 'A shiny new gadget.' }
            },
            required: %w[name price]
          }
        },
        required: ['product']
      }

      response(201, 'product created') do
        schema({ '$ref' => '#/components/schemas/Product' })
        let(:product_params) { { product: { name: 'Test', price: 10.0 } } }
        run_test!
      end

      response(422, 'unprocessable entity') do
        run_test!
      end
    end
  end

  path '/api/v1/products/{id}' do
    parameter name: 'id', in: :path, type: :string, format: :uuid, description: 'Product ID'

    get('Shows a single product') do
      tags 'Products'
      produces 'application/json'

      response(200, 'successful') do
        schema({ '$ref' => '#/components/schemas/Product' })
        let(:id) { 'some-uuid' }
        run_test!
      end

      response(404, 'not found') do
        run_test!
      end
    end

    patch('Updates a product') do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :product_params, in: :body, schema: {
        type: :object,
        properties: {
          product: {
            type: :object,
            properties: {
              name: { type: :string, example: 'New Gadget' },
              price: { type: :number, example: 99.99 },
              description: { type: :string, example: 'A shiny new gadget.' }
            },
            required: %w[name price]
          }
        },
        required: ['product']
      }

      response(200, 'successful') do
        schema({ '$ref' => '#/components/schemas/Product' })
        let(:id) { 'some-uuid' }
        let(:product_params) { { product: { name: 'Updated Name' } } }
        run_test!
      end
    end

    delete('Deletes a product') do
      tags 'Products'
      security [Bearer: []]

      response(204, 'no content') do
        let(:id) { 'some-uuid' }
        run_test!
      end
    end
  end

  path '/api/v1/products/{id}/like' do
    post('Likes a product') do
      tags 'Products'
      produces 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, format: :uuid, description: 'Product ID'

      response(200, 'successful') do
        schema type: :object, properties: { message: { type: :string } }
        let(:id) { 'some-uuid' }
        run_test!
      end
    end
  end

  path '/api/v1/products/{id}/rate' do
    post('Rates a product') do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, format: :uuid, description: 'Product ID'
      parameter name: :rating_params, in: :body, schema: {
        type: :object,
        properties: {
          product_rating: {
            type: :object,
            properties: {
              rating: { type: :integer, example: 5, description: 'Rating from 1 to 5' },
              comment: { type: :string, example: 'Great product!', nullable: true }
            },
            required: ['rating']
          }
        },
        required: ['product_rating']
      }

      response(200, 'successful') do
        let(:id) { 'some-uuid' }
        let(:rating_params) { { product_rating: { rating: 5 } } }
        run_test!
      end
    end
  end

  path '/api/v1/products/{id}/comment' do
    post('Adds a comment to a product') do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, format: :uuid, description: 'Product ID'
      parameter name: :comment_params, in: :body, schema: {
        type: :object,
        properties: {
          product_comment: {
            type: :object,
            properties: {
              content: { type: :string, example: 'This is a comment.' },
              parent_id: { type: :integer, example: 1, nullable: true,
                           description: 'ID of the parent comment for a reply' }
            },
            required: ['content']
          }
        },
        required: ['product_comment']
      }

      response(200, 'successful') do
        let(:id) { 'some-uuid' }
        let(:comment_params) { { product_comment: { content: 'Nice!' } } }
        run_test!
      end
    end
  end
end
