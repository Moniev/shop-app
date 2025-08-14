# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class CategoryManagementService
    def create(category_params)
      category = Category.new(category_params)

      ActiveRecord::Base.transaction do
        category.save!
      end

      Services::Result.new(
        success?: true,
        data: { category: category },
        status: :created,
        message: 'Category created successfully.'
      )
    rescue ActiveRecord::RecordInvalid
      Services::Result.new(
        success?: false,
        errors: category.errors.full_messages,
        status: :unprocessable_entity,
        message: 'Category creation failed due to validation errors.'
      )
    rescue StandardError => e
      Rails.logger.error("Category creation failed unexpectedly: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def update(category, category_params)
      return category_not_found_result unless category

      category.update!(category_params)

      Services::Result.new(
        success?: true,
        data: { category: category },
        status: :ok,
        message: 'Category updated successfully.'
      )
    rescue ActiveRecord::RecordInvalid
      Services::Result.new(
        success?: false,
        errors: category.errors.full_messages,
        status: :unprocessable_entity,
        message: 'Category update failed due to validation errors.'
      )
    rescue StandardError => e
      Rails.logger.error("Category update for category #{category.id} failed unexpectedly: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def destroy(category)
      return category_not_found_result unless category

      begin
        ActiveRecord::Base.transaction do
          category.destroy!
        end
        Services::Result.new(
          success?: true,
          status: :no_content,
          message: 'Category deleted successfully.'
        )
      rescue ActiveRecord::RecordNotDestroyed
        Services::Result.new(
          success?: false,
          errors: category.errors.full_messages.presence || ['Category could not be deleted.'],
          status: :unprocessable_entity,
          message: 'Category deletion failed.'
        )
      rescue StandardError => e
        Rails.logger.error("Category deletion for category #{category.id} failed unexpectedly: #{e.message}")
        Services::Result.new(
          success?: false,
          errors: ['An unexpected error occurred.'],
          status: :internal_server_error,
          message: 'An unexpected error occurred.'
        )
      end
    end

    private

    def category_not_found_result
      Services::Result.new(
        success?: false,
        errors: ['Category not found.'],
        status: :not_found,
        message: 'Category not found.'
      )
    end
  end
end
