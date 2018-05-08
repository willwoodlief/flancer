# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180503102325) do

  create_table "flancer_freelancer_jobs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
    t.integer "internal_id"
    t.boolean "is_read", default: false, null: false
    t.string "star_color"
    t.text "link", null: false
    t.string "star_symbol"
    t.text "price_hint"
    t.text "number_bids"
    t.text "title"
    t.text "description"
    t.text "tags"
    t.text "status"
    t.text "when_posted"
    t.text "comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["internal_id"], name: "index_flancer_freelancer_jobs_on_internal_id", unique: true
    t.index ["is_read"], name: "index_flancer_freelancer_jobs_on_is_read"
    t.index ["link"], name: "index_flancer_freelancer_jobs_on_link", unique: true, length: { link: 210 }
  end

end
