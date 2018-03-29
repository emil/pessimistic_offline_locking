 ---

### *Pessimistic Offline Lock*

Vanilla Rails App with Examples: https://github.com/emil/pessimistic_offline_locking
---
### Purpose
*"Prevents conflicts between concurrent business transactions by allowing only one business transaction at a time to access data."
* (https://martinfowler.com/eaaCatalog/pessimisticOfflineLock.html)
---
* Typical Business Scenarios
* Editing/accessing complex business objects such as Work Orders, Patient Records, Insurance cases, Recurring Plans etc
* Lets consider Hospital Patient Management system : 
** entities: Physician, Appointments, Patients, Prescriptions,  Wards, Insurances
** physician has_many patients, patients has many prescriptions, treatments, insurances
** general requirement: editing a Patient (or subordinate entities) should be performed one business transaction at a time.
---
![Sequence Diagram](/app/assets/images/pessimistic_offline_lock.png)
---
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
  ...
  Patient.find(id).with_pessimistic_lock(current_user, 'editing') do |p|
    p.prescriptions.build(name: "Amoxicillin 250mg"....
    p.appointments.build(name: "Follow Up"....
    
  end
```
---
Unit Test Example
---
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
* Object ID (usually ActiveRecord PK)
* Object Type Object Class (Patient etc)
---


- Controller action with the Pessimistic Lock
- Typical 

``` ruby

```

---
### Thank you
* (http://github.com/emil/pessimistic_offline_locking)
* Emil Marcetta
---
