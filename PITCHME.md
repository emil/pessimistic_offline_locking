 ---

### *Pessimistic Offline Lock*

Vanilla Rails App with Examples 
https://github.com/emil/pessimistic_offline_locking
---
#### Purpose
_Prevents conflicts between concurrent business transactions by allowing only one business transaction at a time to access data._
(https://martinfowler.com/eaaCatalog/pessimisticOfflineLock.html)
---
#### Scenarios
* Editing/accessing complex business objects such as 
 - Work Orders
 - Patient Records 
 - Insurance cases
 - Processing Recurring Plans
 
---
Consider Hospital Patient Management system
* Entities
 - Patient
 - Physician
 - Appointment
 - Prescriptions 
 - Insurances
---
Hospital Patient Management system
![Model Diagram](/app/assets/images/has_many_through.png)
* Physician has_many Patients,Patient has many Prescriptions, Appointments, Insurances
---

General requirement: editing a Patient (or associated entity) should be performed one business transaction at a time.
![Sequence Diagram](/app/assets/images/pessimistic_offline_lock.png)
---
- Acquire Pessimistic Lock before updating
- Start/End block *defines* the beg/end of the Pessimistic Offline Lock

``` ruby
  class Patient < ApplicationRecord
    include ActiveRecord::PessimisticLocking
    
    has_many :appointments
    has_many :prescriptions
    has_many :physicians, through: :appointments
    has_many :insurances
    ....
  end
  
  # acquire patient lock and update
  
  Patient.find(id).with_pessimistic_lock(current_user, 'editing') do |p|
    p.prescriptions.build(name: "Amoxicillin 250mg"....
    p.appointments.build(name: "Follow Up"....
    
  end
```
---
Unit Test Example
``` ruby
   test "concurrent patient edit not allowed" do

     Patient.first.with_pessimistic_lock(current_user, 'editing') do |p|
     
       # different user - unable to obtain the lock
       assert !p.acquire_pessimistic_lock('lock holder 2', 'editing')

       # same user is ok (reentrant lock)
       assert p.acquire_pessimistic_lock(current_user, 'editing')
     end
   end

```
---
Pessimistic Lock Table

``` sql
+----------------+--------------+------+-----+---------+----------------+
| Field          | Type         | Null | Key | Default | Extra          |
+----------------+--------------+------+-----+---------+----------------+
| id             | bigint(20)   | NO   | PRI | NULL    | auto_increment |
| object_type    | varchar(100) | NO   |     | NULL    |                |
| lock_object_id | varchar(100) | NO   | MUL | NULL    |                |
| lock_holder    | varchar(100) | NO   |     | NULL    |                |
| reason         | varchar(100) | YES  |     | NULL    |                |
| expiry_handler | varchar(100) | YES  |     | NULL    |                |
| created_at     | datetime     | NO   |     | NULL    |                |
| updated_at     | datetime     | NO   | MUL | NULL    |                |
+----------------+--------------+------+-----+---------+----------------+
```
* Lock Holder  - user/session etc holding a lock
* Object ID (usually ActiveRecord PK)
* Object Type Object Class (Patient etc)
---
Patient Lock acquiring

``` ruby
Patient.find(id).with_pessimistic_lock(current_user, 'editing') do |p|
  ....
end
```

``` sql
+----+-------------+----------------+-------------+---------+----------------+---------------------+---------------------+
| id | object_type | lock_object_id | lock_holder | reason  | expiry_handler | created_at          | updated_at          |
+----+-------------+----------------+-------------+---------+----------------+---------------------+---------------------+
|  2 | Patient     | 298486374      | Dr_Green    | editing | NULL           | 2018-03-29 23:33:53 | 2018-03-29 23:33:53 |
+----+-------------+----------------+-------------+---------+----------------+---------------------+---------------------+
```
---
- Controller action acquiring the Pessimistic Lock
``` ruby
  before_action :acquire_patient_lock, :only => [:new, :create, :edit, :update]

  # acquire/reacquire patient lock
  def acquire_patient_lock
    unless Patient.find(params[:patient_id]).acquire_pessimistic_lock(current_user, action_name)
      render :nothing => true, :status => :precondition_failed
    end
  end
  private :acquire_patient_lock
  
  def new
    @prescription = Prescription.new(:patient_id => params[:patient_id])
  end

```
---
- Controller action re-acquiring the Pessimistic Lock
``` ruby
  before_action :acquire_patient_lock, :only => [:new, :create, :edit, :update]

  # acquire/reacquire patient lock
  def acquire_patient_lock
    unless Patient.find(params[:patient_id]).acquire_pessimistic_lock(current_user, action_name)
      render :nothing => true, :status => :precondition_failed
    end
  end
  private :acquire_patient_lock
  
  def create
    @prescription = Prescription.new(prescription_params)

    respond_to do |format|
      if @prescription.save
        # release lock
        @prescription.patient.release_pessimistic_lock
        format.html { redirect_to @prescription, notice: 'Prescription was successfully created.' }
        format.json { render :show, status: :created, location: @prescription }
      else
        format.html { render :new }
        format.json { render json: @prescription.errors, status: :unprocessable_entity }
      end
    end
  end
```
---
Reusable/genral purpose
 - Delayed/Active Job
 - Worker
 - etc
---
### Thank you
* (http://github.com/emil/pessimistic_offline_locking)
* Emil Marcetta
---
