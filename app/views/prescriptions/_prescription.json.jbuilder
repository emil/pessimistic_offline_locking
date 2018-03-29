json.extract! prescription, :id, :name, :patient_id, :drug, :issued_at, :created_at, :updated_at
json.url prescription_url(prescription, format: :json)
