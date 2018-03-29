# -*- coding: utf-8 -*-
require File.expand_path('../../test_helper', __FILE__)

class Patient < ActiveRecord::Base
  include ActiveRecord::PessimisticLocking
end

class PessimisticLockTest < MiniTest::Test
  include LogCapture::Assertions

  def setup
    PessimisticLock.delete_all
  end

  def test_validations
    refute PessimisticLock.new({}).valid?
    good_params = {:lock_object_id => 'good', :object_type => 'nice', :lock_holder => 'entitiy'}
    assert  PessimisticLock.new(good_params).valid?
    assert  PessimisticLock.new(good_params).valid?

    refute PessimisticLock.new(good_params.merge(:lock_object_id=>nil)).valid?
    refute PessimisticLock.new(good_params.merge(:lock_object_id=>'')).valid?
    refute PessimisticLock.new(good_params.merge(:lock_object_id=>' ')).valid?
    refute PessimisticLock.new(good_params.merge(:object_type=>nil)).valid?
    refute PessimisticLock.new(good_params.merge(:object_type=>'')).valid?
    refute PessimisticLock.new(good_params.merge(:object_type=>' ')).valid?

    # lock_holder can be the empty string.
    refute PessimisticLock.new(good_params.merge(:lock_holder=>nil)).valid?
    assert PessimisticLock.new(good_params.merge(:lock_holder=>'')).valid?
    assert PessimisticLock.new(good_params.merge(:lock_holder=>' ')).valid?

    # look at maximum lengths
    too_long = 'x' * 101
    [:lock_object_id, :object_type, :lock_holder, :reason, :expiry_handler].each do |field|
      refute PessimisticLock.new(good_params.merge(field => too_long)).valid?
    end
  end

  def test_cannot_lock_unsaved_record
    b = Patient.new(Patient.first.attributes.merge(:id => nil))
    assert_raises ActiveRecord::RecordInvalid do
      refute PessimisticLock.acquire(b, 'unit test holder')
    end

    b.valid?
    assert b.save
    begin
      assert PessimisticLock.acquire(b, 'unit test holder')
    rescue
      refute "should not have raised exception"
    end
  end

  def test_lock_with_expiry_handler_is_not_expired
    b = Patient.first
    assert b.acquire_pessimistic_lock('ordinary_holder', 'testing lock expiry', :expiry_handler => 'test expiry handler')
    lock = PessimisticLock.find_for(b)
    refute lock.expired?
    ActiveRecord::Base.connection.execute "update pessimistic_locks set updated_at = '2010/01/01'"
    lock.reload
    refute lock.expired?
  end

  def test_lock_with_expiry_handler_prevents_other_lock
    b = Patient.first
    assert b.acquire_pessimistic_lock('ordinary_holder', 'testing lock expiry', :expiry_handler => 'test expiry handler')
    ActiveRecord::Base.connection.execute "update pessimistic_locks set updated_at = '2010/01/01'"
    refute b.acquire_pessimistic_lock('other holder', 'testing one time lock')
  end

  def test_single_lock
    b = Patient.first
    assert PessimisticLock.acquire(b, 'unit test holder')
    refute PessimisticLock.acquire(b, 'unit test other holder')
  end

  def test_multiple_locks
    batches = Patient.all[0,2]
    assert_equal 2, batches.length
    assert PessimisticLock.acquire(batches, 'unit test holder')
    refute PessimisticLock.acquire(batches, 'unit test other holder')

    batches.each { |b|
      refute PessimisticLock.acquire(b, 'unit test other holder')
      assert PessimisticLock.acquire(b, 'unit test holder')
    }
    assert_equal 2, PessimisticLock.release(batches, 'unit test holder')
  end

  def test_multiple_locks_unique_constraint_invoked
    batch = Patient.first
    assert PessimisticLock.acquire(batch, 'unit test holder')

    # The find statement is within PessimisticLock.transaction / method PessimisticLock::acquire
    PessimisticLock.expects(:where).returns(stub(:to_a => []))
    PessimisticLock.expects(:log_debug).with('Acquiring lock failed with "Mysql2::Error: Duplicate entry".')
    refute PessimisticLock.acquire(batch, 'unit test other holder')
  end

  def test_adding_locks
    batches = Patient.all[0,2]
    assert PessimisticLock.acquire(batches.first, 'unit test holder')
    assert PessimisticLock.acquire(batches, 'unit test holder')
    assert_equal 2, PessimisticLock.release(batches, 'unit test holder')
  end

  def test_acquire_existing_locks_not_updated
    lock_holder = 'test lh'

    # Create two locks (one may be enough)
    assert_equal 0, PessimisticLock.count
    pair_1 = {:lock_object_id => 1, :object_type => 2, :lock_holder => lock_holder}
    pair_2 = {:lock_object_id => 3, :object_type => 4, :lock_holder => lock_holder}
    lock_1 = PessimisticLock.create(pair_1)
    lock_2 = PessimisticLock.create(pair_2)
    refute_nil lock_1.id
    refute_nil lock_2.id
    assert_equal 2, PessimisticLock.count

    # Push them into the past
    time_in_past = 5.minutes.ago.utc
    PessimisticLock.connection.execute("update pessimistic_locks set updated_at='#{time_in_past.to_s(:db)}', created_at = '#{time_in_past.to_s(:db)}'")
    lock_1.reload
    lock_2.reload
    # look up the updated_at field that lock_1 / lock_2 have in the database
    time_set = lock_1.updated_at
    assert_equal time_set, lock_2.updated_at # they have the same

    # Set up two targets, so that one's object-id, and the other's type_id
    # matches lock_1
    target_stub_1  = stub('target stub 1', :pessimistic_lock_object_id => 1, :object_type => 5)
    target_stub_2  = stub('target stub 2', :pessimistic_lock_object_id => 4, :object_type => 2)

    # Now invoke PessimisticLock.acquire
    assert PessimisticLock.acquire([target_stub_1, target_stub_2], lock_holder)

    # It should not affect lock_1's timestamp
    lock_1.reload
    assert_equal time_set, lock_1.updated_at # lock_1 is not changed

    # It should not affect lock_2's timestamp
    lock_2.reload
    assert_equal time_set, lock_2.updated_at # lock_2 is not changed
  end

  def test_acquire_existing_locks_are_updated
    lock_holder = 'test lh'

    # Create two locks (one may be enough)
    assert_equal 0, PessimisticLock.count
    pair_1 = {:lock_object_id => 1, :object_type => 2, :lock_holder => lock_holder}
    pair_2 = {:lock_object_id => 3, :object_type => 4, :lock_holder => lock_holder}
    lock_1 = PessimisticLock.create(pair_1)
    lock_2 = PessimisticLock.create(pair_2)
    refute_nil lock_1.id
    refute_nil lock_2.id
    assert_equal 2, PessimisticLock.count

    # Push them into the past
    time_in_past = 5.minutes.ago.utc
    PessimisticLock.connection.execute("update pessimistic_locks set updated_at='#{time_in_past.to_s(:db)}', created_at = '#{time_in_past.to_s(:db)}'")
    lock_1.reload
    lock_2.reload
    # look up the updated_at field that lock_1 / lock_2 have in the database
    time_set = lock_1.updated_at
    assert_equal time_set, lock_2.updated_at # they have the same

    # Set up two targets, one of them has the same object_id / object_type as pair_1
    target_stub_1  = stub('target stub 1', :pessimistic_lock_object_id => 1, :object_type => 2)
    target_stub_2  = stub('target stub 2', :pessimistic_lock_object_id => 4, :object_type => 2)

    # Now invoke PessimisticLock.acquire
    assert PessimisticLock.acquire([target_stub_1, target_stub_2], lock_holder)

    # It should affect lock_1's timestamp
    lock_1.reload
    refute_equal time_set, lock_1.updated_at # lock_1 is now changed:
    assert time_set < lock_1.updated_at, "#{time_set} should be before #{lock_1.updated_at}" # it is later

    # It should not affect lock_2's timestamp
    lock_2.reload
    assert_equal time_set, lock_2.updated_at # lock_2 is not changed
  end

  def test_acquire_escapes
    target_stub  = stub('target stub 1', :pessimistic_lock_object_id => "'", :object_type => "''")

    # Now invoke PessimisticLock.acquire
    # The select statement corresponding to target_stub
    # looks like  SELECT * FROM `pessimistic_locks` WHERE ((object_id, object_type) in (('\'', '\'\'')))

    assert PessimisticLock.acquire(target_stub, 'lock_holder')
    refute PessimisticLock.acquire(target_stub, 'other lock_holder')

    target_stub  = stub('target stub 2', :pessimistic_lock_object_id => '"', :object_type => '""')

    assert PessimisticLock.acquire(target_stub, 'lock_holder 2')
    refute PessimisticLock.acquire(target_stub, 'other lock_holder 2')
  end

  def test_releasing_records_dont_exist
    lock_holder = 'test lh'

    # Create two locks
    assert_equal 0, PessimisticLock.count
    pair_1 = {:lock_object_id => 1, :object_type => 2,:lock_holder => lock_holder}
    pair_2 = {:lock_object_id => 3, :object_type => 4, :lock_holder => lock_holder}
    lock_1 = PessimisticLock.create(pair_1)
    lock_2 = PessimisticLock.create(pair_2)
    refute_nil lock_1.id
    refute_nil lock_2.id
    assert_equal 2, PessimisticLock.count

    # Set up two targets, so that one's object-id, and the other's type_id
    # matches lock_1
    target_stub_1  = stub('target stub 1', :pessimistic_lock_object_id => 1, :object_type => 5)
    target_stub_2  = stub('target stub 2', :pessimistic_lock_object_id => 4, :object_type => 2)

    # Now invoke PessimisticLock.release
    assert PessimisticLock.release([target_stub_1, target_stub_2], lock_holder)

    # It should not affect lock_1 and lock_2
    assert lock_1.reload
    assert lock_2.reload
    assert_equal 2, PessimisticLock.count
  end

  def test_releasing_records_exist
    lock_holder = 'test lh'
    # Create two locks
    assert_equal 0, PessimisticLock.count
    pair_1 = {:lock_object_id => 1, :object_type => 2,:lock_holder => lock_holder}
    pair_2 = {:lock_object_id => 3, :object_type => 4, :lock_holder => lock_holder}
    lock_1 = PessimisticLock.create(pair_1)
    lock_2 = PessimisticLock.create(pair_2)
    refute_nil lock_1.id
    refute_nil lock_2.id
    assert_equal 2, PessimisticLock.count
    lock_1_stub = stub('release stub 1', :pessimistic_lock_object_id => lock_1[:lock_object_id], :object_type => lock_1[:object_type])
    lock_2_stub = stub('release stub 2', :pessimistic_lock_object_id => lock_2[:lock_object_id], :object_type => lock_2[:object_type])
    assert PessimisticLock.release([lock_1_stub, lock_2_stub], lock_holder)

    assert_equal 0, PessimisticLock.count
  end

  def test_one_time_lock_I
    b = Patient.first

    # Get a one-time lock for the record
    assert b.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')
    assert b.pessimistic_lock_acquired?

    # Can't acquire lock a second time.
    refute b.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')
    refute b.acquire_pessimistic_lock('some other holder', 'testing one time lock')

    # Doesn't depend on the instance, but the database record
    b2 = Patient.find(b.id)
    refute b2.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')
    refute b2.acquire_pessimistic_lock('some other holder', 'testing one time lock')

  end

  def test_one_time_lock_II
    b = Patient.first

    # Get an ordinary lock for the record
    assert b.acquire_pessimistic_lock('ordinary holder', 'testing one time lock')
    assert b.pessimistic_lock_acquired?

    # Can't acquire lock a second time.
    refute b.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')

    # Doesn't depend on the instance, but the database record
    b2 = Patient.find(b.id)
    refute b2.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')
    refute b2.acquire_pessimistic_lock('some other holder', 'testing one time lock')
  end

  def test_acquire_one_time_lock_I
    b = Patient.first
    # Get a one-time lock for the record with the special method
    assert b.acquire_one_time_pessimistic_lock('testing one time lock')
    assert b.pessimistic_lock_acquired?
    refute b.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')
    refute b.acquire_one_time_pessimistic_lock('testing one time lock')
    refute b.acquire_one_time_pessimistic_lock('testing one time lock other reason')

    # Doesn't depend on the instance, but the database record
    b2 = Patient.find(b.id)
    refute b2.acquire_pessimistic_lock(ActiveRecord::PessimisticLocking::ONE_TIME_LOCKING_LOCK_HOLDER, 'testing one time lock')
    refute b2.acquire_pessimistic_lock('some other holder', 'testing one time lock')

    assert b.release_one_time_pessimistic_lock
  end

  def test_acquire_one_time_lock_II
    b = Patient.first
    # Get an ordinary lock for the record
    assert b.acquire_pessimistic_lock('ordinary_holder', 'testing one time lock')
    assert b.pessimistic_lock_acquired?
    refute b.acquire_one_time_pessimistic_lock('testing one time lock')

    # Doesn't depend on the instance, but the database record
    b2 = Patient.find(b.id)
    refute b2.acquire_one_time_pessimistic_lock('testing one time lock')
  end

  def test_with_one_time_pessimistic_lock_I
    b = Patient.first
    b.with_one_time_pessimistic_lock('testing one time lock') do
      assert b.pessimistic_lock_acquired?
      refute b.acquire_pessimistic_lock('some other holder', 'testing one time lock')

      # Doesn't depend on the instance, but the database record
      b2 = Patient.find(b.id)
      refute b2.acquire_one_time_pessimistic_lock('testing one time lock')
    end
    refute b.pessimistic_lock_acquired?
    assert b.acquire_pessimistic_lock('some other holder', 'testing one time lock')
  end

  def test_with_one_time_pessimistic_lock_II
    b = Patient.first
    # Get an ordinary lock for the record
    assert b.acquire_pessimistic_lock('ordinary_holder', 'testing one time lock')
    assert_raises ActiveRecord::PessimisticLockingError do
      b.with_one_time_pessimistic_lock('testing one time lock') {}
    end
  end

  def test_acquire_lock_with_expiry_handler_module_method
    b = Patient.first
    # Get an ordinary lock for the record
    PessimisticLock.destroy_all
    assert b.acquire_pessimistic_lock('ordinary_holder', 'testing one time lock', :expiry_handler => 'test expiry handler')
    assert b.pessimistic_lock_acquired?
    refute b.acquire_one_time_pessimistic_lock('testing one time lock')

    # Expire the lock
    expired = 20.minutes.ago
    PessimisticLock.update_all(updated_at:expired)

    # read the lock back before deleting expired
    locks = PessimisticLock.all
    assert_equal 1, locks.length
    lock = locks.first
    assert (expired.to_i - lock.updated_at.to_i).abs < 10  # don't care about +- some seconds

    PessimisticLock.delete_expired!

    assert_equal lock, PessimisticLock.first # is still there and hasn't canged
  end

  # Unfortunately there are two methods that do the same
  # one in the module one in the class
  def test_acquire_lock_with_expiry_handler_class_method
    b = Patient.first
    # Get an ordinary lock for the record
    PessimisticLock.destroy_all
    assert PessimisticLock.acquire([b], 'ordinary_holder', 'testing one time lock', :expiry_handler => 'test expiry handler')
    refute b.acquire_one_time_pessimistic_lock('testing one time lock')

    # Expire the lock
    expired = 20.minutes.ago
    PessimisticLock.update_all(updated_at:expired)

    # read the lock back before deleting expired
    locks = PessimisticLock.all
    assert_equal 1, locks.length
    lock = locks.first
    assert (expired.to_i - lock.updated_at.to_i).abs < 10  # don't care about +- some seconds

    PessimisticLock.delete_expired!

    assert_equal lock, PessimisticLock.first # is still there and hasn't canged
  end

  def test_acquire_lock_class_method_updates_expiry_handler
    b = Patient.first
    b2 = Patient.last

    # b.expects(:pessimistic_lock_object_id).returns(1).at_least(1)
    # b2.expects(:pessimistic_lock_object_id).returns(2).at_least(1)
    # Get an ordinary lock for the record
    PessimisticLock.destroy_all
    test_holder = 'test holder'
    test_expiry_handler = 'test expiry handler'
    b.acquire_pessimistic_lock(test_holder, 'test expiry handler update') # no handler
    assert_equal [nil], PessimisticLock.all.collect { |lock| lock.expiry_handler}
    assert PessimisticLock.acquire([b,b2], test_holder, 'testing one time lock', :expiry_handler => test_expiry_handler)
    # Now both have the test_expiry_handler
    assert_equal [test_expiry_handler,test_expiry_handler], PessimisticLock.all.collect { |lock| lock.expiry_handler}
  end

  def test_release_lock_ignores_expiry_handler
    b = Patient.first
    b2 = Patient.last
    test_holder = 'test holder'

    assert_equal 0, PessimisticLock.count
    b.acquire_pessimistic_lock(test_holder, 'test reason')
    b2.acquire_pessimistic_lock(test_holder, 'test reason', :expiry_handler => 'expiry handler')
    assert_equal 2, PessimisticLock.count
    assert_equal [b.pessimistic_lock_object_id.to_s,b2.pessimistic_lock_object_id.to_s].sort, PessimisticLock.where(lock_holder: test_holder).collect { |lock| lock.lock_object_id}.sort

    assert_equal 2,  PessimisticLock.release( [b,b2], test_holder)
    assert_equal 0, PessimisticLock.count
  end

  def test_acquire_lock_force_new_instance_methods
    b = Patient.first
    b2 = Patient.last

    PessimisticLock.destroy_all
    test_holder = 'test holder'
    test_expiry_handler = 'test expiry handler'
    assert b.acquire_pessimistic_lock(test_holder, 'test expiry handler update')
    refute b.acquire_pessimistic_lock(test_holder, 'test expiry handler update', :force_new=>true)
    assert b.acquire_pessimistic_lock(test_holder, 'test expiry handler update', :force_new=>false)
    assert b.acquire_pessimistic_lock(test_holder, 'test expiry handler update')
  end

  def test_acquire_lock_force_new_class_method
    b = Patient.first
    b2 = Patient.last

    PessimisticLock.destroy_all
    test_holder = 'test holder'
    test_expiry_handler = 'test expiry handler'
    assert b.acquire_pessimistic_lock(test_holder, 'test expiry handler update')
    refute PessimisticLock.acquire([b], test_holder, 'test expiry handler update', :force_new=>true)
    assert PessimisticLock.acquire([b], test_holder, 'test expiry handler update', :force_new=>false)
    assert b.acquire_pessimistic_lock(test_holder, 'test expiry handler update', :force_new=>false)
    assert PessimisticLock.acquire([b], test_holder, 'test expiry handler update')
    assert b.acquire_pessimistic_lock(test_holder, 'test expiry handler update')
  end

  def test_acquire_lock_and_release_doesnt_release_others
    b1 = Patient.first
    b2 = Patient.last
    refute_equal b1.id, b2.id

    PessimisticLock.destroy_all

    assert b1.acquire_pessimistic_lock('test holder 1', 'test reason')
    assert_equal 1, PessimisticLock.count
    assert b2.acquire_pessimistic_lock('test holder 2', 'test reason 2')
    assert_equal 2, PessimisticLock.count

    # Now release b1's lock.
    assert b1.release_pessimistic_lock('test holder 1')

    # b2 should still be locked
    assert_equal 1, PessimisticLock.count
  end
end
