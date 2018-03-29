require 'active_record/pessimistic_locking' 

# A class that allows obtaining a pessimistic lock without an ActiveRecord instance
class Pessimism
  include ActiveRecord::PessimisticLocking

  attr_reader :pessimistic_lock_object_id, :object_type 
  def initialize(pessimistic_lock_object_id, object_type = 'Pessimism')
    @pessimistic_lock_object_id = pessimistic_lock_object_id
    @object_type = object_type
  end
end
