# The GCS service-agent lookup initializes the identity when it does not exist.
# Keeping it separate lets key grants wait for the identity before buckets exist.
data "google_storage_project_service_account" "this" {
  project = var.project_id
}
