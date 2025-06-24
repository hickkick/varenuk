class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.bigint :telegram_id, null: false
      t.string :username
      t.string :language_code
      t.timestamps
    end
    add_index :users, :telegram_id, unique: true
  end
end
