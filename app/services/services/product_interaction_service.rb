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
  class ProductInteractionService
    def initialize(user)
      @user = user
    end

    def like(product)
      if ProductLike.exists?(user: @user, product: product)
        return Services::Result.new(
          success?: false,
          errors: ['You have already liked this product.'],
          status: :conflict,
          message: 'Product already liked.'
        )
      end

      product_like = ProductLike.create!(user: @user, product: product)
      Services::Result.new(
        success?: true,
        data: { product_like: product_like },
        status: :created,
        message: 'Product liked successfully.'
      )
    rescue ActiveRecord::RecordInvalid => e
      Services::Result.new(
        success?: false,
        errors: product_like.errors.full_messages,
        status: :unprocessable_content,
        message: 'Failed to like product.'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to like product #{product.id} by user #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while liking the product.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def unlike(product)
      product_like = ProductLike.find_by(user: @user, product: product)

      unless product_like
        Services::Result.new(
          success?: false,
          errors: ['You have not liked this product.'],
          status: :not_found,
          message: 'Product like not found.'
        )
      end
      product_like.destroy!
      Services::Result.new(
        success?: true,
        data: {},
        status: :ok,
        message: 'Product unliked successfully.'
      )
    rescue ActiveRecord::RecordNotDestroyed => e
      Services::Result.new(
        success?: false,
        errors: product_like.errors.full_messages,
        status: :unprocessable_content,
        message: 'Failed to unlike product.'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to unlike product #{product.id} by user #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while unliking the product.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def rate(product, rating, comment = nil)
      unless rating.present? && (1..5).include?(rating.to_i)
        return Services::Result.new(
          success?: false,
          errors: ['Rating must be an integer between 1 and 5.'],
          status: :unprocessable_content,
          message: 'Invalid rating value.'
        )
      end

      product_rate = ProductRate.find_or_initialize_by(user: @user, product: product)
      product_rate.update!(rating: rating.to_i, comment: comment)
      Services::Result.new(
        success?: true,
        data: { product_rate: product_rate },
        status: product_rate.previous_changes.key?('id') ? :created : :ok,
        message: product_rate.previous_changes.key?('id') ? 'Product rated successfully.' : 'Product rating updated successfully.'
      )
    rescue ActiveRecord::RecordInvalid => e
      Services::Result.new(
        success?: false,
        errors: product_rate.errors.full_messages,
        status: :unprocessable_content,
        message: 'Failed to rate product.'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to rate product #{product.id} by user #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while rating the product.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def add_comment(product, content, parent_id = nil)
      unless content.present?
        return Services::Result.new(
          success?: false,
          errors: ['Comment content cannot be empty.'],
          status: :unprocessable_content,
          message: 'Empty comment content.'
        )
      end

      parent = Comment.find_by(id: parent_id) if parent_id.present?
      unless parent_id.blank? || (parent && parent.product == product)
        return Services::Result.new(
          success?: false,
          errors: ['Invalid parent comment ID.'],
          status: :unprocessable_content,
          message: 'Invalid parent comment.'
        )
      end

      comment = Comment.new(user: @user, product: product, content: content, parent: parent)
      comment.save!

      Services::Result.new(
        success?: true,
        data: { comment: comment },
        status: :created,
        message: 'Comment added successfully.'
      )
    rescue ActiveRecord::RecordInvalid => e
      Services::Result.new(
        success?: false,
        errors: comment.errors.full_messages,
        status: :unprocessable_content,
        message: 'Failed to add comment.'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to add comment to product #{product.id} by user #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while adding the comment.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def update_comment(comment, new_content)
      unless comment.user == @user || @user.admin? || @user.moderator?
        return Services::Result.new(
          success?: false,
          errors: ['You are not authorized to edit this comment.'],
          status: :forbidden,
          message: 'Authorization failed.'
        )
      end

      comment.update!(content: new_content)
      Services::Result.new(
        success?: true,
        data: { comment: comment },
        status: :ok,
        message: 'Comment updated successfully.'
      )
    rescue ActiveRecord::RecordInvalid => e
      Services::Result.new(
        success?: false,
        errors: comment.errors.full_messages,
        status: :unprocessable_content,
        message: 'Failed to update comment.'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to update comment #{comment.id} by user #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while updating the comment.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def remove_comment(comment)
      unless comment.user == @user || @user.admin? || @user.moderator?
        return Services::Result.new(
          success?: false,
          errors: ['You are not authorized to remove this comment.'],
          status: :forbidden,
          message: 'Authorization failed.'
        )
      end

      comment.destroy!
      Services::Result.new(
        success?: true,
        data: {},
        status: :ok,
        message: 'Comment removed successfully.'
      )
    rescue ActiveRecord::RecordNotDestroyed => e
      Services::Result.new(
        success?: false,
        errors: comment.errors.full_messages,
        status: :unprocessable_content,
        message: 'Failed to remove comment.'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to remove comment #{comment.id} by user #{@user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred while removing the comment.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
