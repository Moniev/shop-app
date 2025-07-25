# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
# frozen_string_literal: true

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
        Services::Result.new(success?: false, errors: @user.errors.full_messages, status: :unprocessable_entity,
                             message: 'Profile update failed.')
      end
    rescue StandardError => e
      Rails.logger.error("User profile update failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during profile update.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def update_location(location_params)
      user_detail = @user.user_detail || @user.build_user_detail

      unless user_detail.present?
        return Services::Result.new(success?: false, errors: ['User details record not found.'], status: :not_found,
                                    message: 'Cannot update location: User details missing.')
      end

      if user_detail.update(location_params)
        Services::Result.new(success?: true, data: { user_detail: user_detail }, status: :ok,
                             message: 'Location updated successfully.')
      else
        Services::Result.new(success?: false, errors: user_detail.errors.full_messages,
                             status: :unprocessable_entity, message: 'Location update failed.')
      end
    rescue StandardError => e
      Rails.logger.error("User location update failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during location update.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def update_details(user_detail_params)
      user_detail = @user.user_detail || @user.build_user_detail

      unless user_detail.present?
        return Services::Result.new(success?: false, errors: ['User details record not found.'], status: :not_found,
                                    message: 'Cannot update details: User details missing.')
      end

      if user_detail.update(user_detail_params)
        Services::Result.new(success?: true, data: { user_detail: user_detail }, status: :ok,
                             message: 'Personal details updated successfully.')
      else
        Services::Result.new(success?: false, errors: user_detail.errors.full_messages,
                             status: :unprocessable_entity, message: 'Personal details update failed.')
      end
    rescue StandardError => e
      Rails.logger.error("User details update failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during details update.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def update_entrepreneur_details(entrepreneur_detail_params)
      unless @user.has_role?(:entrepreneur)
        return Services::Result.new(success?: false, errors: ['User is not an entrepreneur.'], status: :forbidden,
                                    message: 'Access denied: Not an entrepreneur.')
      end
      unless @user.active? && @user.verified?
        return Services::Result.new(success?: false, errors: ['User account is not active or verified.'],
                                    status: :forbidden, message: 'Cannot update: User account not active or verified.')
      end

      entrepreneur_detail = @user.entrepreneur_detail || @user.build_entrepreneur_detail

      if entrepreneur_detail.update(entrepreneur_detail_params)
        Services::Result.new(success?: true, data: { entrepreneur_detail: entrepreneur_detail }, status: :ok,
                             message: 'Entrepreneur details updated successfully.')
      else
        Services::Result.new(success?: false, errors: entrepreneur_detail.errors.full_messages,
                             status: :unprocessable_entity, message: 'Entrepreneur details update failed.')
      end
    rescue StandardError => e
      Rails.logger.error("Entrepreneur details update failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false,
                           errors: ['An unexpected error occurred during entrepreneur details update.'], status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def destroy_user
      if @user.destroy
        Services::Result.new(success?: true, status: :no_content, message: 'User account deleted successfully.')
      else
        Services::Result.new(success?: false, errors: @user.errors.full_messages, status: :unprocessable_entity,
                             message: 'Failed to delete user account.')
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error("User deletion failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: @user.errors.full_messages, status: :unprocessable_entity,
                           message: 'Failed to delete user account due to dependencies.')
    rescue StandardError => e
      Rails.logger.error("Unexpected error during user deletion for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during user deletion.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end

    def update_role(new_role)
      unless User.roles.keys.include?(new_role.to_s)
        return Services::Result.new(success?: false, errors: ["Invalid role: #{new_role}"],
                                    status: :unprocessable_entity, message: 'Invalid role provided.')
      end

      if @user.update(role: new_role)
        Services::Result.new(success?: true, data: { user: @user }, status: :ok,
                             message: "User role updated to #{new_role} successfully.")
      else
        Services::Result.new(success?: false, errors: @user.errors.full_messages, status: :unprocessable_entity,
                             message: 'User role update failed.')
      end
    rescue StandardError => e
      Rails.logger.error("User role update failed for user #{@user.id}: #{e.message}")
      Services::Result.new(success?: false, errors: ['An unexpected error occurred during role update.'],
                           status: :internal_server_error, message: 'An unexpected error occurred.')
    end
  end
end
