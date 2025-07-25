# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Authentication', type: :request do
  let(:test_user) { create(:user) }
  let(:Authorization) { "Bearer #{generate_jwt_for(test_user)}" }

  path '/api/v1/auth/login' do
    post('Logs a user in') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, format: :email, example: 'user@example.com' },
          password: { type: :string, format: :password, example: 'password123' }
        },
        required: %w[mail password]
      }

      response(200, 'successful login (2FA disabled)') do
        schema type: :object,
               properties: {
                 token: { type: :string,
                          example: 'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE2NzgwMDgwMDB9.sig' }
               }
        let(:credentials) { { mail: 'user@example.com', password: 'password' } }
        run_test!
      end

      response(202, '2FA code sent') do
        schema type: :object,
               properties: {
                 message: { type: :string, example: '2FA code sent to your email' }
               }
        let(:credentials) { { mail: 'user_with_2fa@example.com', password: 'password' } }
        run_test!
      end

      response(401, 'unauthorized') do
        schema type: :object,
               properties: {
                 errors: { type: :array, items: { type: :string }, example: ['Invalid email or password'] }
               }
        let(:credentials) { { mail: 'user@example.com', password: 'wrongpassword' } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/verify_2fa' do
    post('Verifies a 2FA code') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :verification, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, format: :email, example: 'user@example.com' },
          second_factor_code: { type: :string, example: '1a2b3c4d' }
        },
        required: %w[mail second_factor_code]
      }

      response(200, 'successful') do
        schema type: :object,
               properties: {
                 token: { type: :string,
                          example: 'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE2NzgwMDgwMDB9.sig' }
               }
        let(:verification) { { mail: 'user@example.com', second_factor_code: '123456' } }
        run_test!
      end

      response(401, 'unauthorized') do
        schema type: :object,
               properties: {
                 errors: { type: :array, items: { type: :string }, example: ['Invalid 2FA code'] }
               }
        let(:verification) { { mail: 'user@example.com', second_factor_code: 'wrongcode' } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/activate' do
    patch('Activates a user account') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :activation, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, format: :email, example: 'user@example.com' },
          activation_code: { type: :string, example: 'abcdef123456' }
        },
        required: %w[mail activation_code]
      }

      response(200, 'successful') do
        schema type: :object, properties: { message: { type: :string, example: 'Account activated' } }
        let(:activation) { { mail: 'user@example.com', activation_code: 'valid_code' } }
        run_test!
      end

      response(422, 'unprocessable entity') do
        schema type: :object,
               properties: { errors: { type: :array, items: { type: :string },
                                       example: ['Invalid activation code'] } }
        let(:activation) { { mail: 'user@example.com', activation_code: 'invalid_code' } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/verify' do
    patch('Verifies a user account') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :verification, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, format: :email, example: 'user@example.com' },
          verification_code: { type: :string, example: 'abcdef123456' }
        },
        required: %w[mail verification_code]
      }

      response(200, 'successful') do
        schema type: :object, properties: { message: { type: :string, example: 'Account verified' } }
        let(:verification) { { mail: 'user@example.com', verification_code: 'valid_code' } }
        run_test!
      end

      response(422, 'unprocessable entity') do
        schema type: :object,
               properties: { errors: { type: :array, items: { type: :string },
                                       example: ['Invalid verification code'] } }
        let(:verification) { { mail: 'user@example.com', verification_code: 'invalid_code' } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/password/reset' do
    post('Requests a password reset code') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :reset_request, in: :body, schema: {
        type: :object,
        properties: { mail: { type: :string, format: :email, example: 'user@example.com' } },
        required: ['mail']
      }

      response(200, 'successful') do
        schema type: :object,
               properties: { message: { type: :string,
                                        example: 'If an account with that email exists, we have sent password reset instructions.' } }
        let(:reset_request) { { mail: 'user@example.com' } }
        run_test!
      end
    end

    patch('Resets password with a code') do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :reset_confirmation, in: :body, schema: {
        type: :object,
        properties: {
          reset_code: { type: :string, example: 'xyz789abc' },
          password: { type: :string, format: :password, example: 'newPassword123' },
          password_confirmation: { type: :string, format: :password, example: 'newPassword123' }
        },
        required: %w[reset_code password password_confirmation]
      }

      response(200, 'successful') do
        schema type: :object,
               properties: { message: { type: :string,
                                        example: 'Password has been reset successfully.' } }
        let(:reset_confirmation) { { reset_code: 'valid_code', password: 'new', password_confirmation: 'new' } }
        run_test!
      end

      response(422, 'unprocessable entity') do
        schema type: :object,
               properties: { errors: { type: :array, items: { type: :string },
                                       example: ['Invalid or expired reset code'] } }
        let(:reset_confirmation) { { reset_code: 'invalid_code', password: 'new', password_confirmation: 'new' } }
        run_test!
      end
    end
  end
end
