# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class UserProfileService
    def initialize(user)
      @user = user
    end

    def update_profile(params)
      if @user.update(params)
        Services::Result.new(success?: true, data: { user: @user }, status: :ok,
                             message: 'Profile updated successfully.')
      else
        Services::Result.new(success?: false, errors: @user.errors.full_messages, status: :unprocessable_content,
                             message: 'Profile update failed.')
      end
    end

    def update_location(location_params)
      user_detail = @user.user_detail || @user.build_user_detail
      location = user_detail.locations.first || user_detail.locations.build

      if location.update(location_params)
        Services::Result.new(success?: true, data: { location: location }, status: :ok,
                             message: 'Location updated successfully.')
      else
        Services::Result.new(success?: false, errors: location.errors.full_messages,
                             status: :unprocessable_content, message: 'Location update failed.')
      end
    end

    def update_details(user_detail_params)
      user_detail = @user.user_detail || @user.build_user_detail

      if user_detail.update(user_detail_params)
        Services::Result.new(success?: true, data: { user_detail: user_detail }, status: :ok,
                             message: 'Personal details updated successfully.')
      else
        Services::Result.new(success?: false, errors: user_detail.errors.full_messages,
                             status: :unprocessable_content, message: 'Personal details update failed.')
      end
    end

    def update_entrepreneur_details(entrepreneur_detail_params)
      unless @user.entrepreneur?
        return Services::Result.new(success?: false, errors: ['User is not an entrepreneur.'], status: :forbidden,
                                    message: 'Access denied: Not an entrepreneur.')
      end
      unless @user.active? && @user.verified?
        return Services::Result.new(success?: false, errors: ['User account is not active or verified.'],
                                    status: :forbidden, message: 'Cannot update: User account not active or verified.')
      end

      user_detail = @user.user_detail || @user.build_user_detail
      entrepreneur_detail = user_detail.entrepreneur_detail || user_detail.build_entrepreneur_detail

      if entrepreneur_detail.update(entrepreneur_detail_params)
        Services::Result.new(success?: true, data: { entrepreneur_detail: entrepreneur_detail }, status: :ok,
                             message: 'Entrepreneur details updated successfully.')
      else
        Services::Result.new(success?: false, errors: entrepreneur_detail.errors.full_messages,
                             status: :unprocessable_content, message: 'Entrepreneur details update failed.')
      end
    end

    def destroy_user
      @user.destroy!
      Services::Result.new(success?: true, status: :no_content, message: 'User account deleted successfully.')
    rescue ActiveRecord::RecordNotDestroyed => e
      Services::Result.new(
        success?: false,
        errors: @user.errors.full_messages.presence || [e.message],
        status: :unprocessable_content,
        message: 'Failed to delete user account.'
      )
    rescue StandardError => e
      Rails.logger.error("Unexpected error during user deletion for ID #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def update_role(new_role)
      unless User.roles.keys.include?(new_role.to_s)
        return Services::Result.new(success?: false, errors: ["Invalid role: #{new_role}"],
                                    status: :unprocessable_content, message: 'Invalid role provided.')
      end

      if @user.update(role: new_role)
        Services::Result.new(success?: true, data: { user: @user }, status: :ok,
                             message: "User role updated to #{new_role} successfully.")
      else
        Services::Result.new(success?: false, errors: @user.errors.full_messages, status: :unprocessable_content,
                             message: 'User role update failed.')
      end
    rescue StandardError => e
      Rails.logger.error("User role update failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during role update.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end
  end
end
