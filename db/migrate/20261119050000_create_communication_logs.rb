class CreateCommunicationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :communication_logs do |t|
      t.string :direction, null: false # inbound: Shopify -> アプリ / outbound: アプリ -> Shopify
      t.string :category, null: false  # page / webhook / api / auth / admin_api など
      t.string :http_method, null: false
      t.string :url, null: false
      t.string :shop_domain
      t.json :request_headers
      t.text :request_body
      t.integer :status
      t.json :response_headers
      t.text :response_body
      t.integer :duration_ms
      t.string :error
      t.datetime :created_at, null: false
    end

    add_index :communication_logs, :created_at
  end
end
