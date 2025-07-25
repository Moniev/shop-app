class AddReferencesToProductLikes < ActiveRecord::Migration[8.0]
  def change
    add_reference :product_likes, :user, null: false, foreign_key: true
    add_reference :product_likes, :product, null: false, foreign_key: true
  end
end
