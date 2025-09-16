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
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    def self.call(user_params)
      if User.exists?(mail: user_params[:mail])
        return conflict_result(errors: ['User with this email already exists'], message: 'User registration failed')
      end

      if user_params[:phone].present? && User.exists?(phone: user_params[:phone])
        return conflict_result(errors: ['User with this phone already exists'], message: 'User registration failed')
      end

      with_error_handling do
        ActiveRecord::Base.transaction do
          user = User.new(user_params)
          user.save!
          user.create_activation_code!(code: SecureRandom.hex(4))
          success_result(data: { user: user }, message: 'User registered succesfully. Activation code sent',
                         status: :created)
        end
      end
    end
  end
end
