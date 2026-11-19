class CreateShops < ActiveRecord::Migration[8.1]
  def change
    create_table :shops do |t|
      t.string :shopify_domain, null: false
      t.string :shopify_token, null: false
      t.string :access_scopes, default: "", null: false
      t.datetime :expires_at
      t.string :refresh_token
      t.datetime :refresh_token_expires_at
      t.timestamps
    end

    add_index :shops, :shopify_domain, unique: true
  end
end
