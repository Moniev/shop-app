class Category < ApplicationRecord
  has_many :category, class_name: 'Category'
end
