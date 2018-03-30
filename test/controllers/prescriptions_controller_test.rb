require_relative '../test_helper'

class PrescriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dr_green = Physician.find_by_name 'Dr_Green'
    @dr_ngui = Physician.find_by_name 'Dr_Ngui'
    
    @prescription = prescriptions(:one)
  end

  test "should get index" do
    get prescriptions_url
    assert_response :success
  end

  test "should get new" do
    controller.session[:user_id] = @request.session[:user_id] = @dr_green.id
    
    get new_prescription_url, params: {patient_id: Patient.first.id }
    assert_response :success
  end
  
=begin
  test "should create prescription" do
    assert_difference('Prescription.count') do
      post prescriptions_url, params: { prescription: { drug: @prescription.drug, issued_at: @prescription.issued_at, name: @prescription.name, patient_id: @prescription.patient_id } }
    end

    assert_redirected_to prescription_url(Prescription.last)
  end

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
end
