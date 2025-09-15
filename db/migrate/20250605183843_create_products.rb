class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.decimal :weight_kg, precision: 10, scale: 2
      t.decimal :height_cm, precision: 10, scale: 2
      t.decimal :width_cm, precision: 10, scale: 2
      t.decimal :length_cm, precision: 10, scale: 2
      t.string :type
      t.text :description
      t.timestamps
    end
  end
end
