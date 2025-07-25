# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Users', type: :request do
  let(:test_user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_jwt_for(test_user)}" }

  path '/api/v1/users' do
    get('Lists all users (Admin only)') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :page, in: :query, type: :integer, required: false

      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/User' }
        run_test!
      end
    end

    post('Creates a new user (registration)') do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              mail: { type: :string, format: :email, example: 'newuser@example.com' },
              password: { type: :string, format: :password, example: 'password123' },
              password_confirmation: { type: :string, format: :password, example: 'password123' },
              phone: { type: :string, example: '123456789', nullable: true },
              user_detail_attributes: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'John_Doe123!' },
                  first_name: { type: :string, example: 'John' },
                  last_name: { type: :string, example: 'Doe' }
                }
              }
            },
            required: %w[mail password password_confirmation]
          }
        },
        required: ['user']
      }

      response(201, 'user created') do
        schema '$ref' => '#/components/schemas/User'
        let(:user_params) { { user: { mail: 'test@test.com', password: 'p', password_confirmation: 'p' } } }
        run_test!
      end

      response(422, 'unprocessable entity') do
        let(:user_params) { { user: { mail: 'invalid', password: 'p', password_confirmation: 'p' } } }
        run_test!
      end
    end
  end

  path '/api/v1/users/me' do
    get('Shows the current user profile') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/User'
        run_test!
      end
    end
  end

  path '/api/v1/users/logout' do
    post('Logs out the current user') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema type: :object, properties: { message: { type: :string, example: 'Logged out' } }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'User ID'

    get('Shows a single user') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]

      response(200, 'successful') do
        schema '$ref' => '#/components/schemas/User'
        let(:id) { '123' }
        run_test!
      end
    end

    patch('Updates a user') do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              mail: { type: :string, format: :email },
              password: { type: :string, format: :password },
              password_confirmation: { type: :string, format: :password },
              phone: { type: :string },
              user_detail_attributes: {
                type: :object,
                properties: {
                  first_name: { type: :string },
                  last_name: { type: :string }
                }
              }
            }
          }
        }
      }

      response(200, 'successful') do
        let(:id) { '123' }
        let(:user_params) { { user: { phone: '555444333' } } }
        run_test!
      end
    end

    delete('Deletes a user') do
      tags 'Users'
      security [Bearer: []]

      response(204, 'no content') do
        let(:id) { '123' }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/role/update' do
    patch('Updates a user role (Admin only)') do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, description: 'User ID'
      parameter name: :role_params, in: :body, schema: {
        type: :object,
        properties: { role: { type: :string, enum: %w[regular moderator admin] } },
        required: ['role']
      }

      response(200, 'successful') do
        let(:id) { '123' }
        let(:role_params) { { role: 'moderator' } }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/actions' do
    get("Lists a user's actions") do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, description: 'User ID'
      parameter name: :page, in: :query, type: :integer, required: false

      response(200, 'successful') do
        let(:id) { '123' }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/update_location' do
    patch('Updates user location details') do
      tags 'Users'
      consumes 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, description: 'User ID'
      parameter name: :location_params, in: :body, schema: {
        type: :object,
        properties: {
          location: {
            type: :object,
            properties: {
              country: { type: :string, example: 'Poland' },
              province: { type: :string, example: 'Masovian' },
              city: { type: :string, example: 'Warsaw' },
              postal_code: { type: :string, example: '00-001' },
              street: { type: :string, example: 'Main Street' },
              building_number: { type: :integer, example: 10 },
              apartment_number: { type: :integer, example: 5, nullable: true }
            },
            required: %w[country province city postal_code]
          }
        },
        required: ['location']
      }

      response(200, 'successful') do
        let(:id) { '123' }
        let(:location_params) do
          { location: { country: 'Poland', province: 'Lesser Poland', city: 'Krakow', postal_code: '30-001' } }
        end
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/update_details' do
    patch('Updates user personal details') do
      tags 'Users'
      consumes 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, description: 'User ID'
      parameter name: :details_params, in: :body, schema: {
        type: :object,
        properties: {
          user_detail: {
            type: :object,
            properties: {
              first_name: { type: :string, example: 'John' },
              last_name: { type: :string, example: 'Doe' },
              name: { type: :string, example: 'John Doe' }
            }
          }
        },
        required: ['user_detail']
      }

      response(200, 'successful') do
        let(:id) { '123' }
        let(:details_params) { { user_detail: { first_name: 'Jane' } } }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/update_entrepreneur_details' do
    patch('Updates user entrepreneur details') do
      tags 'Users'
      consumes 'application/json'
      security [Bearer: []]
      parameter name: 'id', in: :path, type: :string, description: 'User ID'
      parameter name: :entrepreneur_params, in: :body, schema: {
        type: :object,
        properties: {
          entrepreneur_detail: {
            type: :object,
            properties: {
              business_name: { type: :string },
              nip: { type: :string },
              krs: { type: :string },
              description: { type: :string },
              offer: { type: :string },
              income: { type: :number, format: :float },
              costs: { type: :number, format: :float },
              funding_capital: { type: :number, format: :float },
              industry: { type: :string },
              business_phone_number: { type: :string },
              business_mail: { type: :string, format: :email },
              website_address: { type: :string, format: :uri },
              management_council_members: { type: :object, properties: {} },
              decision_makers: { type: :object, properties: {} }
            }
          }
        },
        required: ['entrepreneur_detail']
      }

      response(200, 'successful') do
        let(:id) { '123' }
        let(:entrepreneur_params) { { entrepreneur_detail: { business_name: 'New Business Inc.' } } }
        run_test!
      end
    end
  end
end
