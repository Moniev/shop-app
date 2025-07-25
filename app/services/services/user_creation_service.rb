# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class UserCreationService
    def self.call(user_params)
      user = User.new(user_params)
      begin
        ActiveRecord::Base.transaction do
          user.save!
          user.create_activation_code!(code: SecureRandom.hex(16))
        end
        Services::Result.new(
          success?: true,
          data: { user: user },
          status: :created,
          message: 'User registered successfully. Activation code sent.'
        )
      rescue ActiveRecord::RecordInvalid => e
        Services::Result.new(
          success?: false,
          errors: user.errors.full_messages,
          status: :unprocessable_entity,
          message: 'User registration failed due to validation errors.'
        )
      rescue StandardError => e
        Rails.logger.error("User creation failed: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred during user registration.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end
  end
end
