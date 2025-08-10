# frozen_string_literal: true

ActiveRecord::Base.transaction do
  [User, Category, Product, Comment, ProductLike, ProductRate].each(&:destroy_all)
end
