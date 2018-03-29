require 'active_record/pessimistic_lock'

module ActiveRecord

  class PessimisticLockingError < ActiveRecordError
  end

  module PessimisticLocking

    attr_accessor :pessimistic_lock
    attr_accessor :pessimistic_lock_reason

    @pessimistic_lock = false
    @pessimistic_lock_reason = ''

    def pessimistic_lock_acquired?
      @pessimistic_lock
    end

    # Default value
    def pessimistic_lock_object_id
      self.send(self.class.primary_key)
    end

    # Default value
    def object_type
      self.class.to_s
    end

    def release_pessimistic_lock(lock_holder)
      PessimisticLock.release(self, lock_holder || '')
    end

    # Use empty string for one-time locks
    # (Might also use *.)
    ONE_TIME_LOCKING_LOCK_HOLDER  = '' unless defined?(ONE_TIME_LOCKING_LOCK_HOLDER)  # We already have the lock! Update the time stamp, and the reason


    # lock_holder should not have the ONE_TIME_LOCKING_LOCK_HOLDER value to acquire an ordinary lock
    # return true or false, depending on whether the lock was acquired
    def acquire_pessimistic_lock(lock_holder, reason, options = {})
      lock_options = options
      if ONE_TIME_LOCKING_LOCK_HOLDER == lock_holder
        lock_options = { :only_once => true }.merge(options)
      end
      self.pessimistic_lock = PessimisticLock.acquire(self, lock_holder || '', reason, lock_options)

      @pessimistic_lock_reason = (_(PessimisticLock.find_for(self).reason) rescue '') unless self.pessimistic_lock
      self.pessimistic_lock
    end

    def with_pessimistic_lock(lock_holder, reason, &block)

      if !self.acquire_pessimistic_lock(lock_holder, reason)
        raise ActiveRecord::PessimisticLockingError.new('Lock could not be acquired.')
      end

      begin
        yield self if block_given?
      ensure
        self.release_pessimistic_lock(lock_holder)
      end
    end

    #
    # One-time locks.
    #
    # Can only be acquired once, regardless of lock_holder and reason.
    #
    # Any subsequent lock acquisition will fail
    #
    def acquire_one_time_pessimistic_lock(reason)
      acquire_pessimistic_lock(ONE_TIME_LOCKING_LOCK_HOLDER,reason)
    end

    def release_one_time_pessimistic_lock
      release_pessimistic_lock(ONE_TIME_LOCKING_LOCK_HOLDER)
    end

    def with_one_time_pessimistic_lock(reason, &block)
      with_pessimistic_lock(ONE_TIME_LOCKING_LOCK_HOLDER, reason) do
        yield if block_given?
      end
    end

  end
end
