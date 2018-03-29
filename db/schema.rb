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

ActiveRecord::Schema.define(version: 20180329063245) do

  create_table "appointments", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
    t.integer "patient_id"
    t.integer "physician_id"
    t.date "appointment_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "patients", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
    t.text "address"
    t.string "phone"
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pessimistic_locks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "object_type", limit: 100, null: false
    t.string "lock_object_id", limit: 100, null: false
    t.string "lock_holder", limit: 100, null: false
    t.string "reason", limit: 100
    t.string "expiry_handler", limit: 100
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lock_object_id", "object_type"], name: "index_pessimistic_locks_on_lock_object_id_and_object_type", unique: true
    t.index ["updated_at"], name: "index_pessimistic_locks_on_updated_at"
  end

  create_table "physicians", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prescriptions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
    t.integer "patient_id"
    t.string "drug"
    t.date "issued_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
