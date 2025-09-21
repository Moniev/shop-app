class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :payment, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true

      t.string :invoice_number, null: false

      t.decimal :tax_rate, null: false, precision: 5, scale: 2
      t.float :tax_value, null: false, precision: 5, scale: 2

      t.float :total_gross, null: false, precision: 5, scale: 2
      t.float :total_net, null: false, precision: 5, scale: 2

      t.timestamps
    end
  end
end
