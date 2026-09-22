# GCS service-agent initialization

This narrow module exposes only the Google provider's `google_storage_project_service_account` data source. Looking up the GCS service agent initializes it if needed. The Stack runs it before key-level IAM and encrypted bucket creation.

The upstream [Cloud Storage root module at 12.3.0](https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v12.3.0/main.tf) does not initialize this identity. Its [simple_bucket submodule](https://github.com/terraform-google-modules/terraform-google-cloud-storage/blob/v12.3.0/modules/simple_bucket/main.tf) does, but couples the lookup to bucket creation; waiting for that component from the bucket's encryption-key IAM would create a dependency cycle. Its internal-key path also changes ownership to a separate key per bucket.

The generic Service Usage identity resource is not an equivalent GCS lookup: [upstream issue 19970](https://github.com/hashicorp/terraform-provider-google/issues/19970) documents missing Storage identity attributes. The dedicated [provider data source](https://github.com/hashicorp/terraform-provider-google/blob/v7.44.0/website/docs/d/storage_project_service_account.html.markdown) is the supported operation.

This is the recorded upstream gap under ADR 0005. It contains no bucket or key resources, credentials, deployment names, backend or provisioner. Cloud execution still requires an approved operation; local validation does not call the lookup.
