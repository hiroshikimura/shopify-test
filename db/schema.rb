# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_19_050000) do
  create_table "communication_logs", force: :cascade do |t|
    t.string "direction", null: false
    t.string "category", null: false
    t.string "http_method", null: false
    t.string "url", null: false
    t.string "shop_domain"
    t.json "request_headers"
    t.text "request_body"
    t.integer "status"
    t.json "response_headers"
    t.text "response_body"
    t.integer "duration_ms"
    t.string "error"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_communication_logs_on_created_at"
  end

  create_table "shops", force: :cascade do |t|
    t.string "shopify_domain", null: false
    t.string "shopify_token", null: false
    t.string "access_scopes", default: "", null: false
    t.datetime "expires_at"
    t.string "refresh_token"
    t.datetime "refresh_token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shopify_domain"], name: "index_shops_on_shopify_domain", unique: true
  end
end
