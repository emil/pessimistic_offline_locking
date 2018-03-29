class CreatePrescriptions < ActiveRecord::Migration[5.1]
  def change
    create_table :prescriptions do |t|
      t.string :name
      t.integer :patient_id
      t.string :drug
      t.date :issued_at

      t.timestamps
    end
  end
end
