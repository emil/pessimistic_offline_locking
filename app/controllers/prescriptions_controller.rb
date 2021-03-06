class PrescriptionsController < ApplicationController
  before_action :set_prescription, only: [:show, :edit, :update, :destroy]

  # GET /prescriptions
  # GET /prescriptions.json
  def index
    @prescriptions = Prescription.all
  end

  # GET /prescriptions/1
  # GET /prescriptions/1.json
  def show
  end

  before_action :acquire_patient_lock, :only => [:new, :create, :edit, :update]

  # acquire/reacquire patient lock
  def acquire_patient_lock

    @patient = Patient.find(params[:patient_id])
    
    unless @patient.acquire_pessimistic_lock(current_user, action_name)
      @prescription ||= Prescription.new(:patient_id => params[:patient_id])
      @prescription.errors[:base] << "Unable to acquire Patient Edit Lock"
      logger.info "Unable to acquire lock for the user #{current_user.name}"
    end
  end
  private :acquire_patient_lock
  
  # GET /prescriptions/new
  def new
    @prescription ||= Prescription.new(:patient_id => params[:patient_id])
  end

  # GET /prescriptions/1/edit
  def edit
  end

  # POST /prescriptions
  # POST /prescriptions.json
  def create
    @prescription = Prescription.new(prescription_params)

    respond_to do |format|
      if @prescription.save
        @patient.release_pessimistic_lock(current_user)
        format.html { redirect_to @prescription, notice: 'Prescription was successfully created.' }
        format.json { render :show, status: :created, location: @prescription }
      else
        format.html { render :new }
        format.json { render json: @prescription.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /prescriptions/1
  # PATCH/PUT /prescriptions/1.json
  def update
    respond_to do |format|
      if @prescription.update(prescription_params)
        format.html { redirect_to @prescription, notice: 'Prescription was successfully updated.' }
        format.json { render :show, status: :ok, location: @prescription }
      else
        format.html { render :edit }
        format.json { render json: @prescription.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /prescriptions/1
  # DELETE /prescriptions/1.json
  def destroy
    @prescription.destroy
    respond_to do |format|
      format.html { redirect_to prescriptions_url, notice: 'Prescription was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_prescription
      @prescription = Prescription.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def prescription_params
      params.require(:prescription).permit(:name, :patient_id, :drug, :issued_at)
    end

    private
    def current_user
      # test sets thread variable
      @current_user ||= Thread.current.thread_variable_get(:user)
    end
end
