# frozen_string_literal: true

require 'jwt'

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles operations for User resources via the API.
    #
    # Provides endpoints for user registration, profile management, role updates,
    # and action history. It supports authentication and authorization for secure access.
    class UsersController < ApplicationController
      skip_before_action :authenticate_user!, only: [:create]
      load_and_authorize_resource except: %i[create me logout]

      # POST /api/v1/users
      #
      # Creates a new user account (registration).
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `create.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::UserCreationService.call
      def create
        result = Services::UserCreationService.call(user_params)
        bind_data_and_render(result, :show)
      end

      # GET /api/v1/users/:id
      #
      # Retrieves a single user by their ID.
      #
      # @return [void] Implicitly renders the `@user` using `show.json.jbuilder` with a
      #   status of `:ok` (200).
      def show
        bind_data_and_render(nil, :show)
      end

      # PATCH/PUT /api/v1/users/:id
      #
      # Updates an existing user's information.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `update.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::UserProfileService#update_profile
      def update
        result = user_profile_service.update_profile(user_params)
        bind_data_and_render(result, :show)
      end

      # PATCH /api/v1/users/:id/update_location
      #
      # Updates the user's location information.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `update_location.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::UserProfileService#update_location
      def update_location
        result = user_profile_service.update_location(location_params)
        @user.reload if result.success?
        bind_data_and_render(result, :show)
      end

      # PATCH /api/v1/users/:id/update_details
      #
      # Updates the user's personal details.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `update_details.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::UserProfileService#update_details
      def update_details
        result = user_profile_service.update_details(user_detail_params)
        @user.reload if result.success?
        bind_data_and_render(result, :show)
      end

      # PATCH /api/v1/users/:id/update_entrepreneur_details
      #
      # Updates the user's entrepreneur-specific details.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `update_entrepreneur_details.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::UserProfileService#update_entrepreneur_details
      def update_entrepreneur_details
        result = user_profile_service.update_entrepreneur_details(entrepreneur_detail_params)
        @user.reload if result.success?
        bind_data_and_render(result, :show)
      end

      # DELETE /api/v1/users/:id
      #
      # Deletes a user account.
      #
      # @return [void] Sets instance variables. For success (204 No Content), Rails
      #   will automatically set the status and return no content. For errors, it
      #   implicitly renders `destroy.json.jbuilder` (or `show.json.jbuilder`).
      # @see Services::UserProfileService#destroy_user
      def destroy
        result = user_profile_service.destroy_user
        handle_destroy_response(result)
      end

      # GET /api/v1/users/me
      #
      # Retrieves the profile of the currently authenticated user.
      #
      # @return [void] Sets `@user` to `current_user` and implicitly renders
      #   `me.json.jbuilder` with a status of `:ok` (200).
      def me
        @user = current_user
        bind_data_and_render(nil, :show)
      end

      # GET /api/v1/users
      #
      # Retrieves a paginated list of all users (Admin only).
      #
      # @param [Integer] :page (Optional) The page number for pagination.
      #
      # @return [void] Sets `@users` for the Jbuilder view, implicitly rendering
      #   `index.json.jbuilder` with a status of `:ok` (200).
      def index
        @users = @users.page(params[:page]).per(25)
        bind_data_and_render(nil, :index)
      end

      # PATCH /api/v1/users/:id/role/update
      #
      # Updates the role of a specific user (Admin only).
      #
      # @param [String] :role The new role for the user (e.g., "moderator", "admin").
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `role.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::UserProfileService#update_role
      def role
        result = user_profile_service.update_role(params[:role])
        bind_data_and_render(result, :show)
      end

      # POST /api/v1/users/logout
      #
      # Logs out the current user by blacklisting their JWT.
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `logout.json.jbuilder` with an appropriate status.
      # @see Services::AuthenticationService#blacklist_token (assuming this lives here or a new service)
      def logout
        token = request.headers['Authorization']&.split&.last
        authorize! :logout, current_user
        result = Services::AuthenticationService.blacklist_token(token)
        bind_data_and_render(result)
      end

      # GET /api/v1/users/:id/actions
      #
      # Retrieves a paginated history of a user's actions.
      #
      # @return [void] Sets `@actions` for the Jbuilder view, implicitly rendering
      #   `actions.json.jbuilder` with a status of `:ok` (200).
      def actions
        @actions = @user.user_actions.page(params[:page]).per(25)
        bind_data_and_render(nil, :actions)
      end

      private

      def authorize_role
        authorize! :role, @user
      end

      # Initializes and returns an instance of UserProfileService for the loaded @user.
      # @return [Services::UserProfileService] An instance of UserProfileService.
      def user_profile_service
        @user_profile_service ||= Services::UserProfileService.new(@user)
      end

      # Defines permitted parameters for creating or updating a user.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[name first_name last_name]
        )
      end

      # Defines permitted parameters for updating a user's location.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def location_params
        params.require(:location).permit(
          :country, :province, :city, :postal_code, :street,
          :building_number, :apartment_number
        )
      end

      # Defines permitted parameters for updating a user's personal details.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def user_detail_params
        params.require(:user_detail).permit(:name, :first_name, :last_name)
      end

      # Defines permitted parameters for updating a user's entrepreneur details.
      # @return [ActionController::Parameters] An object with the permitted parameters.
      def entrepreneur_detail_params
        params.require(:entrepreneur_detail).permit(
          :business_name, :nip, :krs, :description, :offer, :income, :costs,
          :funding_capital, :industry, :business_phone_number, :business_mail,
          :website_address,
          management_council_members: {},
          decision_makers: {}
        )
      end

      def bind_data_and_render(result, view_name = nil)
        if result
          bind_data(result)
          if @success
            @user = @data[:user] if @data.key?(:user)
            @users = @data[:users] if @data.key?(:users)

            if view_name
              render view_name, status: @status
            else
              render json: { message: @message }, status: @status
            end
          else
            render json: { errors: @errors }, status: @status
          end
        else
          render view_name, status: :ok
        end
      end

      def handle_destroy_response(result)
        bind_data(result)
        if @success
          head :no_content
        else
          render json: { errors: @errors }, status: @status
        end
      end
    end
  end
end
