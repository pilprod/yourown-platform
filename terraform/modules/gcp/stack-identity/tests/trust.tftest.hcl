mock_provider "google" {}

variables {
  project_id   = "example-platform"
  hcp_stack_id = "st-example"
  name_prefix  = "example-hcp"
  hcp          = { organization = "example", project = "core", stack = "runtime", deployment = "test" }
}

run "phase_scoped_federation" {
  command = plan
  assert {
    condition     = google_service_account.phase["plan"].account_id != google_service_account.phase["apply"].account_id
    error_message = "Plan and apply must not share a service account."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.hcp.oidc[0].issuer_uri == "https://app.terraform.io"
    error_message = "Federation must use the approved issuer."
  }
  assert {
    condition     = contains(google_iam_workload_identity_pool_provider.hcp.oidc[0].allowed_audiences, "gcp.workload.identity")
    error_message = "Token audience must be explicitly restricted."
  }
  assert {
    condition     = strcontains(google_iam_workload_identity_pool_provider.hcp.attribute_condition, "assertion.terraform_stack_id ==") && !strcontains(google_iam_workload_identity_pool_provider.hcp.attribute_condition, "*")
    error_message = "Trust must bind the immutable Stack ID without wildcards."
  }
  assert {
    condition     = google_service_account_iam_member.federation["plan"].role == "roles/iam.workloadIdentityUser"
    error_message = "Federation must use the narrow impersonation role."
  }
}

run "disable_new_federation" {
  command = plan
  variables { disabled = true }
  assert {
    condition     = google_iam_workload_identity_pool_provider.hcp.disabled && google_iam_workload_identity_pool.hcp.disabled
    error_message = "Incident response must disable both the pool and provider."
  }
}
