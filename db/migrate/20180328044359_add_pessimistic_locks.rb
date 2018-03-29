class AddPessimisticLocks < ActiveRecord::Migration[5.1]
  def change
    create_table :pessimistic_locks, :options => 'engine=InnoDB default charset=utf8' do |t|
      t.column :object_type, :string, :limit => 100, :null => false
      t.column :lock_object_id, :string, :limit => 100, :null => false
      t.column :lock_holder, :string, :limit => 100, :null => false
      t.column :reason, :string, :limit => 100, :null => true
      t.column :expiry_handler, :string, :limit => 100, :null => true
      
      t.column :created_at, :datetime, :null => false
      t.column :updated_at, :datetime, :null => false
    end
    
    add_index :pessimistic_locks, :updated_at
    add_index :pessimistic_locks, [:lock_object_id, :object_type], :unique => true

  end
end
