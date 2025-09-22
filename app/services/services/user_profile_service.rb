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
    include Concerns::ResultHelpers
    include Concerns::Handlers

    def initialize(user)
      @user = user
    end

    def update_profile(params)
      if @user.update(params)
        success_result(data: { user: @user }, message: 'profile updated successfully')
      else
        unprocessable_content_result(record: @user, message: 'failed to update user profile')
      end
    end

    def update_location(location_params)
      user_detail = @user.user_detail || @user.build_user_detail
      location = user_detail.locations.first || user_detail.locations.build

      if location.update(location_params)
        success_result(data: { location: location }, message: 'Location updated successfully')
      else
        uprocessable_content_result(data: { location: location }, message: 'Failed to update location')
      end
    end

    def update_details(user_detail_params)
      user_detail = @user.user_detail || @user.build_user_detail

      if user_detail.update(user_detail_params)
        success_result(data: { user_detail: user_detail }, message: 'Personal details updated successfully')
      else
        unprocessable_content_result(data: { location: location }, message: 'Failed to update personal data')
      end
    end

    def update_entrepreneur_details(entrepreneur_detail_params)
      unless @user.entrepreneur?
        unauthorized_result(['User is not an entrepreneur'],
                            'Access denied user is not an entrepreneur')
      end

      user_detail = @user.user_detail || @user.build_user_detail
      entrepreneur_detail = user_detail.entrepreneur_detail || user_detail.build_entrepreneur_detail

      if entrepreneur_detail.update(entrepreneur_detail_params)
        success_result(data: { data: entrepreneur_detail }, message: 'Entrepreneur details updated successfully')
      else
        unprocessable_content_result(data: { entrepreneur_detail: entrepreneur_detail },
                                     message: 'Entrepreneur details updated succesfully')
      end
    end

    def destroy_user
      with_error_handling do
        @user.destroy!
        destroy_success_result('User account deleted successfully')
      end
    end

    def update_role(new_role)
      with_error_handling do
        if @user.update(role: new_role)
          success_result(data: { user: @user }, message: "User role updated to #{new_role} successfully")
        else
          unprocessable_content_result(data: { user: @user }, message: 'User role update failed')
        end
      end
    end
  end
end
