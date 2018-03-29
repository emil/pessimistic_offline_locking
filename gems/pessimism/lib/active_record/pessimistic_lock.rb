class PessimisticLock < ActiveRecord::Base

  # How long are we going to be pessimistic for?
  MINUTES_TO_KEEP = 15 unless defined?(MINUTES_TO_KEEP)

  validates_presence_of :lock_object_id
  validates_presence_of :object_type
  validates_exclusion_of :lock_holder, :in => [nil]

  validates_length_of :lock_object_id, :in => (0..100), :allow_nil => true
  validates_length_of :object_type, :in => (0..100), :allow_nil => true
  validates_length_of :lock_holder, :in => (0..100), :allow_nil => true
  validates_length_of :reason, :in => (0..100), :allow_nil => true
  validates_length_of :expiry_handler, :in => (0..100), :allow_nil => true

  # Delete expired locks. Max 50 records will be deleted.
  def self.delete_expired!
    cleanup_limit = 50
    # - lock, prevents multiple engines attempting to remove the same lock and deadlocking.
    plocks = PessimisticLock.select('id').
             where('updated_at < ? and expiry_handler IS NULL', MINUTES_TO_KEEP.minutes.ago).
             limit(cleanup_limit)
                             
    return 0 if plocks.length.zero?
    PessimisticLock.delete(plocks.collect { |l| l.id })
  end

  def expired?
    self.expiry_handler.nil? && self.updated_at < MINUTES_TO_KEEP.minutes.ago
  end

  def self.find_for(argument)
    PessimisticLock.where('lock_object_id = ? and object_type = ?', argument.pessimistic_lock_object_id, argument.object_type).first
  end

  # Acquire pessimistic locks for target(s) with a lock_holder and a reason as a description.
  # If the locks can be acquired, then the expiry_handler will be (re)set for them
  def self.acquire(target, lock_holder, reason = nil, options = {}) # expiry_handler = nil)
    raise ArgumentError if target.blank?
    raise ArgumentError.new('options must be a hash') unless options.is_a?(Hash)
    targets = [*target]
    lock_holder = lock_holder.to_s
    
    begin
      PessimisticLock.transaction do
        existing_locks =  determine_existing_locks(targets)
        return false if !existing_locks.blank? && options[:force_new]

        same_lock_holder = existing_locks.inject(true) do |t, e|
          t &&= (lock_holder == e.lock_holder)
        end

        return false unless same_lock_holder # locked by some other lock_holder
        return false if options[:only_once] && !existing_locks.empty?  # already locked but want "only once"

        # determine targets where locks are added
        targets_with_locks = targets.select do |target|
          existing_locks.detect do |locked_record|
            locked_record.object_type == target.object_type.to_s && locked_record.lock_object_id.to_s == target.pessimistic_lock_object_id.to_s 
          end
        end
        (targets - targets_with_locks).each do |t|
          # make a new lock
          PessimisticLock.create!(:object_type => t.object_type,
                                  :lock_object_id => t.pessimistic_lock_object_id,
                                  :lock_holder => lock_holder,
                                  :reason => reason,
                                  :expiry_handler => options[:expiry_handler])
        end
        #
        # update timestamp on existing locks
        existing_locks.each do |lock|
          lock.reason = reason
          lock.expiry_handler = options[:expiry_handler]
          lock.updated_at = Time.new # ActiveRecord is so clever, it doesn't want to update this field when there are no other changes
          lock.save! # in particular, this will cause an error if the record has expired, and so has been deleted in the mean time by some other agent
        end
      end # PessimisticLock.transaction - note if one create/update fails, all are rolled back
    rescue ActiveRecord::StatementInvalid => e
      log_statement_invalid(e)
      return false
    end
    true
  end

  # Release pessimistic locks for target(s) for a lock_holder.
  # Returns the number of locks released. 0 means no locks were released.
  # Expiry-handler is ignored
  def self.release(target, lock_holder, reason = nil)
    raise ArgumentError if target.blank?
    locks = PessimisticLock.find_for_targets([*target], :lock_holder => lock_holder.to_s)
    locks.each { |r| r.destroy}
    locks.length
  end

  private

  def self.log_statement_invalid(e)
    if e == ActiveRecord::RecordNotUnique
      logger.debug 'Acquiring lock failed with "Duplicate entry".'
    else
      # Not sure when this would happen.
      logger.debug "Acquiring lock failed with ActiveRecord::StatementInvalid", e
    end
  end

  def self.find_for_targets(targets, options = {})
    pairs =  targets.collect { |target| [target.pessimistic_lock_object_id, target.object_type] }
    pairs =  pairs.collect { |t1,t2| [t1.to_s, t2.to_s] }
    pairs =  pairs.collect { |t1,t2| [PessimisticLock.connection.quote_string(t1), PessimisticLock.connection.quote_string(t2)]}
    pairs =  pairs.collect {|t1,t2| "('#{t1}', '#{t2}')"}
    pairs.uniq!
    pairs = pairs.join(',')

    # ActiveRecord doesn't help us to avoid pasting together the SQL statement. That's why we put "pairs" together
    condition = "(lock_object_id, object_type) in (#{pairs})"
    condition << " and lock_holder = :lock_holder " unless options[:lock_holder].blank?
    existing_locks = PessimisticLock.where([condition, options]).to_a
  end

  def self.determine_existing_locks(targets)
    existing_locks = self.find_for_targets(targets)
    unless existing_locks.blank?
      # Remove expired records from existing_locks AND the database
      # "side-effect"
      existing_locks = existing_locks.collect { |existing_lock|
        if existing_lock.expired?
          existing_lock.destroy 
          nil
        else
          existing_lock
        end
      }.compact
    end
    existing_locks
  end
end
