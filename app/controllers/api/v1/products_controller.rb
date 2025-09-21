# frozen_string_literal: true

# Namespace for API resources and controllers.
module Api
  module V1
    # Handles CRUD operations and interactions for Product resources.
    #
    # Provides endpoints to list, show, create, update, and delete products,
    # as well as actions for liking, rating, and commenting.
    # Handles CRUD operations and interactions for Product resources.
    #
    # Provides endpoints to list, show, create, update, and delete products,
    # as well as actions for liking, rating, and commenting.
    class ProductsController < Api::ApplicationController
      skip_before_action :authenticate_user!, only: %i[index show]
      load_and_authorize_resource except: %i[index show]

      # GET /api/v1/products
      #
      # Retrieves a paginated list of products.
      #
      # @param [Integer] :page (Optional) The page number for pagination.
      # @return [void] Sets `@products` for the Jbuilder view, implicitly rendering
      #   `index.json.jbuilder` with a status of `:ok` (200).
      def index
        @products = Product.order(created_at: :desc)
                           .page(params[:page])
                           .includes(:product_photos, :comments, :product_likes, :product_rates)

        render :index, status: :ok
      end

      # GET /api/v1/products/:id
      #
      # Retrieves a single product by its ID.
      #
      # @return [void] Sets `@product` for the Jbuilder view, implicitly rendering
      #   `show.json.jbuilder` with a status of `:ok` (200).
      def show
        @product = Services::ProductCachingService.fetch_one(params[:id])
        handle_show_response(@product)
      end

      # POST /api/v1/products
      #
      # Creates a new product (Admin/Moderator only).
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `create.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::ProductCreationService.call
      def create
        result = Services::ProductCreationService.call(product_params)
        bind_data_and_render(result, :show)
      end

      # PATCH/PUT /api/v1/products/:id
      #
      # Updates an existing product (Admin/Moderator only).
      #
      # @return [void] Sets instance variables, and Rails implicitly renders
      #   `update.json.jbuilder` (or `show.json.jbuilder`) with the appropriate status.
      # @see Services::ProductUpdateService.call
      def update
        result = Services::ProductUpdateService.call(@product, product_params)
        bind_data_and_render(result, :show)
      end

      # DELETE /api/v1/products/:id
      #
      # Deletes a product permanently (Admin/Moderator only).
      #
      # @return [void] Sets instance variables. For success (204 No Content), Rails
      #   will automatically set the status and return no content. For errors, it
      #   implicitly renders `destroy.json.jbuilder` (or `show.json.jbuilder`).
      # @see Services::ProductDeletionService.call
      def destroy
        result = Services::ProductDeletionService.call(@product)
        handle_destroy_response(result)
      end

      # POST /api/v1/products/:id/like
      #
      # Allows an authenticated user to like a product.
      #
      # @return [void] Sets instance variables for the Jbuilder view, implicitly rendering
      #   `like.json.jbuilder` with an appropriate status.
      # @see Services::ProductInteractionService#like
      def like
        result = product_interaction_service.like(@product)
        bind_data_and_render(result, :show)
      end

      # POST /api/v1/products/:id/rate
      #
      # Allows an authenticated user to rate a product.
      #
      # @return [void] Sets instance variables for the Jbuilder view, implicitly rendering
      #   `rate.json.jbuilder` with an appropriate status.
      # @see Services::ProductInteractionService#rate
      def rate
        result = product_interaction_service.rate(@product, rate_params[:rating], rate_params[:comment])
        bind_data_and_render(result, :show)
      end

      # POST /api/v1/products/:id/comment
      #
      # Allows an authenticated user to add a comment to a product.
      #
      # @return [void] Sets instance variables for the Jbuilder view, implicitly rendering
      #   `comment.json.jbuilder` with an appropriate status.
      # @see Services::ProductInteractionService#add_comment
      def comment
        result = product_interaction_service.add_comment(@product, comment_params[:content], comment_params[:parent_id])
        bind_data_and_render(result, :show)
      end

      def available_categories
        @categories = Category.order(:name)
        bind_data_and_render(result, :show)
      end

      def create_category
        result = Services::CategoryManagementService.create(category_params)
        bind_data_and_render(result, :show)
      end

      def update_category
        result = Services::CategoryManagementService.update(@category, category_params)
        bind_data_and_render(result, :show)
      end

      def destroy_category
        result = Services::CategoryManagementServices.delete(@category)
        handle_destroy_response(result)
      end

      private

      def bind_data_and_render(result, view_name)
        if result
          bind_data(result)
          if @success
            @product   = @data[:product]   if @data.key?(:product)
            @products  = @data[:products]  if @data.key?(:products)
            @category  = @data[:category]  if @data.key?(:category)
            @categories = @data[:categories] if @data.key?(:categories)

            @product.reload if @product.present? && @product.persisted? && !@data.key?(:product)

            render view_name, status: @status
          else
            render json: { errors: @errors || [] }, status: @status
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
          render json: { errors: @errors || [] }, status: @status
        end
      end

      def handle_show_response(product)
        if product
          @product = product
          bind_data_and_render(nil, :show)
        else
          render json: { errors: ['Product not found.'] }, status: :not_found
        end
      end

      # Defines permitted parameters for the 'categories' actions.
      # @return [ActionController::Parameters] Permitted parameters.
      def category_params
        params.require(:category).permit(
          :name, :parent_id, product_ids: []
        )
      end

      # Initializes and returns an instance of ProductInteractionService for the current user.
      # @return [Services::ProductInteractionService] An instance of ProductInteractionService.
      def product_interaction_service
        @product_interaction_service ||= Services::ProductInteractionService.new(current_user)
      end

      # Defines permitted parameters for the 'rate' action.
      # @return [ActionController::Parameters] Permitted parameters.
      def rate_params
        params.require(:product_rating).permit(:rating, :comment)
      end

      # Defines permitted parameters for the 'comment' action.
      # @return [ActionController::Parameters] Permitted parameters.
      def comment_params
        params.require(:product_comment).permit(:content, :parent_id)
      end

      # Defines permitted parameters for creating or updating a product.
      # @return [ActionController::Parameters] Permitted parameters.
      def product_params
        params.require(:product).permit(
          :name, :price, :description, :vat_rate,
          product_photos_attributes: %i[id _destroy],
          product_photo_ids: []
        )
      end

      def set_category
        @category = Category.find(params[:category_id])
      end
    end
  end
end
