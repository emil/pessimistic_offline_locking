class CreateAppointments < ActiveRecord::Migration[5.1]
  def change
    create_table :appointments do |t|
      t.string :name
      t.integer :patient_id
      t.integer :physician_id
      t.date :appointment_at

      t.timestamps
    end
  end
end
