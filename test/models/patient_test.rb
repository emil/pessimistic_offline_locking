# require 'test_helper'
require_relative '../test_helper'

class PatientTest < ActiveSupport::TestCase

  test "patient edit with pessimistic lock" do

    Patient.first.with_pessimistic_lock(current_user, 'editing') do |p|
      # p.prescriptions.build(name: "Amoxicillin 250mg"....
     end
   end


   test "concurrent patient edit not allowed" do

     Patient.first.with_pessimistic_lock(current_user, 'editing') do |p|
       # different user - unable to obtain the lock
       assert !p.acquire_pessimistic_lock('lock holder 2', 'editing')

       # same user is ok (reentrant)
       assert p.acquire_pessimistic_lock(current_user, 'editing')
     end
   end

  private
  def current_user(user = 'lock holder 1')
    user
  end
end
