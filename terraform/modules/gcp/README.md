# Local GCP capability gaps

Most infrastructure is composed directly from official modules in [platform-gcp](../../stacks/platform-gcp/README.md). The earlier local API, network, node identity, registry and GKE implementations have been replaced.

Only two narrow local capabilities remain:

- [billing-budget](billing-budget/README.md): explicit currency, actual/forecast thresholds and a resource-level `prevent_destroy` guard. Reviewed upstream budget modules do not cover that combination.
- [storage-service-agent](storage-service-agent/README.md): initialize the GCS service identity through its provider-supported lookup before granting CMEK access and creating encrypted buckets.

Each module documents its upstream comparison, accepts providers from its owning Stack and contains no credentials, backend or deployment defaults. Runtime chart composition lives separately in `modules/runtime`. Follow [Terraform rules](../../../rag/rules/terraform.md) before adding local code.
