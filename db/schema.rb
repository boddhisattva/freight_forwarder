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

ActiveRecord::Schema[8.0].define(version: 2025_06_23_021726) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "exchange_rates", force: :cascade do |t|
    t.datetime "departure_date", null: false
    t.string "currency", limit: 3, null: false
    t.decimal "rate", precision: 10, scale: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["departure_date", "currency"], name: "index_exchange_rates_on_departure_date_and_currency", unique: true
    t.index ["departure_date"], name: "index_exchange_rates_on_departure_date"
    t.check_constraint "rate > 0::numeric", name: "exchange_rates_rate_positive"
  end

  create_table "rates", force: :cascade do |t|
    t.bigint "sailing_id", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "currency", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sailing_id"], name: "index_rates_on_sailing_id", unique: true
    t.check_constraint "amount_cents > 0", name: "rates_amount_cents_positive"
  end

  create_table "sailings", force: :cascade do |t|
    t.string "sailing_code", null: false, comment: "Sailing code"
    t.string "origin_port", null: false, comment: "Origin port"
    t.string "destination_port", null: false, comment: "Destination port"
    t.datetime "departure_date", null: false, comment: "Departure date"
    t.datetime "arrival_date", null: false, comment: "Arrival date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["origin_port", "destination_port"], name: "index_sailings_on_origin_port_and_destination_port"
    t.index ["sailing_code"], name: "index_sailings_on_sailing_code"
  end

  add_foreign_key "rates", "sailings"
end
