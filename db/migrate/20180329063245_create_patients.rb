class CreatePatients < ActiveRecord::Migration[5.1]
  def change
    create_table :patients do |t|
      t.string :name
      t.text :address
      t.string :phone
      t.date :birth_date

      t.timestamps
    end
  end
end
