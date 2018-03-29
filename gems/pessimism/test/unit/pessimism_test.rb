# -*- coding: utf-8 -*-
require File.expand_path('../../test_helper', __FILE__)

class PessimismTest < MiniTest::Test

  def setup
    PessimisticLock.delete_all
  end

  def test_pessimistic_lock_object_id
    assert_equal 'abc', Pessimism.new('abc').pessimistic_lock_object_id
  end

  def test_object_type
    assert_equal 'b', Pessimism.new('a', 'b').object_type
  end

  def test_object_type_default
    assert_equal 'Pessimism', Pessimism.new('a').object_type
  end

  def test_acquire_release_lock
    p = Pessimism.new('a')
    assert PessimisticLock.acquire(p, 'pessimist 1') # can get lock with this lock holder
    assert !PessimisticLock.acquire(p, 'pessimist 2') # not with this one
    assert PessimisticLock.release(p, 'pessimist 1')
    assert PessimisticLock.acquire(p, 'pessimist 2') # now good
  end

  def test_with_pessimistic_lock
    p = Pessimism.new('a')
    p.with_pessimistic_lock('pessimist 1', 'run a quick test') do 
      assert PessimisticLock.acquire(p,'pessimist 1') # lock is acquired
      assert !PessimisticLock.acquire(p,'pessimist 2') # this one is blocked
    end
    assert PessimisticLock.acquire(p,'pessimist 2') # now good
  end

  def test_with_pessimistic_lock_2
    p = Pessimism.new('a')
    p.with_pessimistic_lock('pessimist 1', 'run a quick test') do 
      p2 = Pessimism.new('a') # different instance
      assert PessimisticLock.acquire(p2,'pessimist 1') # lock is acquired
      assert !PessimisticLock.acquire(p2,'pessimist 2') # this one is blocked
    end
    assert PessimisticLock.acquire(p,'pessimist 2') # now good
  end

  def test_with_pessimistic_lock_3
    p = Pessimism.new('a')
    p.with_pessimistic_lock('pessimist 1', 'run a quick test') do 
      p2 = Pessimism.new('a') # different instance
      assert_raises ActiveRecord::PessimisticLockingError do
        p2.with_pessimistic_lock('pessimist 2', 'run a quick test')
      end
    end
  end
end
