require_relative '../test_helper'

class PrescriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dr_green = Physician.find_by_name 'Dr_Green'
    @dr_ngui = Physician.find_by_name 'Dr_Ngui'

    sign_in_as(@dr_green)
    
    @prescription = prescriptions(:one)
  end

  test "should get index" do
    get prescriptions_url
    assert_response :success
  end

  test "concurrent new patient prescriptions not allowed" do

    # as Dr Green
    get new_prescription_url, params: {patient_id: Patient.first.id }
    assert_response :success

    # as Dr Ngui
    sign_in_as(@dr_ngui)
    get new_prescription_url, params: {patient_id: Patient.first.id }

    assert_select 'li', 'Unable to acquire Patient Edit Lock'
  end
  
  test "should create prescription" do
    assert_difference('Prescription.count') do
      post prescriptions_url, params: { prescription: { drug: @prescription.drug, issued_at: @prescription.issued_at, name: @prescription.name, patient_id: @prescription.patient_id }, patient_id: Patient.first.id }
    end

    assert_redirected_to prescription_url(Prescription.last)
  end

=begin

  test "should show prescription" do
    get prescription_url(@prescription)
    assert_response :success
  end

  test "should get edit" do
    get edit_prescription_url(@prescription)
    assert_response :success
  end

  test "should update prescription" do
    patch prescription_url(@prescription), params: { prescription: { drug: @prescription.drug, issued_at: @prescription.issued_at, name: @prescription.name, patient_id: @prescription.patient_id } }
    assert_redirected_to prescription_url(@prescription)
  end

  test "should destroy prescription" do
    assert_difference('Prescription.count', -1) do
      delete prescription_url(@prescription)
    end

    assert_redirected_to prescriptions_url
  end
=end
  private
  #  for the test purposes set the user as Thread Variable
  def sign_in_as(user)
    Thread.current.thread_variable_set(:user, user)
  end
end
