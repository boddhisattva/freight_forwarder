class CreateRates < ActiveRecord::Migration[8.0]
  def change
    create_table :rates do |t|
      t.references :sailing, null: false, foreign_key: true, index: { unique: true }
      t.monetize :amount, currency: { present: false }
      t.string :currency, null: false, limit: 3

      t.timestamps
    end
  end
end
