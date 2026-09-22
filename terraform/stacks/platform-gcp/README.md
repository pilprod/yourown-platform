# GCP platform Stack

This Stack owns one existing target project's API activation and regional network, with opt-in GKE, registries, workload identities, data services and billing prerequisites. It composes official Google modules directly. The separate [agent-runtime Stack](../agent-runtime/README.md) owns Kubernetes and Helm resources.

Status: source migration; validation evidence and remaining acceptance are tracked in [the implementation plan](../../../docs/implementation.md). No Chat resource or state has been adopted. [The migration guide](../../../docs/migrations/yourown-chat.md) records capability mapping and intentional differences.

## Pinned upstream components

Sources and interfaces inspected on 2026-09-22. Links identify the selected revision; read its `variables.tf`, `outputs.tf`, `versions.tf` and license before upgrading.

| Capability | Official source | Release |
| --- | --- | --- |
| APIs and service identities | [Project Factory / project_services](https://github.com/terraform-google-modules/terraform-google-project-factory/tree/v18.3.0/modules/project_services) | 18.3.0 |
| VPC, subnet and secondary ranges | [Network](https://github.com/terraform-google-modules/terraform-google-network/tree/v18.3.0) | 18.3.0 |
| Optional subnet-scoped NAT | [Cloud NAT](https://github.com/terraform-google-modules/terraform-google-cloud-nat/tree/v6.0.0) | 6.0.0 |
| Optional static regional addresses | [Address](https://github.com/terraform-google-modules/terraform-google-address/tree/v5.0.0) | 5.0.0 |
| Node and workload identities | [Service Accounts](https://github.com/terraform-google-modules/terraform-google-service-accounts/tree/v5.0.0) | 5.0.0 |
| Private GKE Standard | [Kubernetes Engine / private-cluster](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/tree/v45.0.0/modules/private-cluster) | 45.0.0 |
| Docker repositories | [Cloud Foundation Fabric / artifact-registry](https://github.com/GoogleCloudPlatform/cloud-foundation-fabric/tree/6f8e3dfeaf4219c1505035c5dab72585a38bf025/modules/artifact-registry) | v58.0.0, full commit pinned |
| Key rings and symmetric keys | [KMS](https://github.com/terraform-google-modules/terraform-google-kms/tree/v4.1.2) | 4.1.2 |
| Buckets | [Cloud Storage](https://github.com/terraform-google-modules/terraform-google-cloud-storage/tree/v12.3.0) | 12.3.0 |
| Private Service Access and PostgreSQL | [SQL DB submodules](https://github.com/terraform-google-modules/terraform-google-sql-db/tree/v28.3.0/modules) | 28.3.0 |
| Empty secret containers | [Secret Manager](https://github.com/GoogleCloudPlatform/terraform-google-secret-manager/tree/v0.9.0) | 0.9.0 |
| Additive IAM | [IAM submodules](https://github.com/terraform-google-modules/terraform-google-iam/tree/v8.2.0/modules) | 8.2.0 |
| Billing export destination dataset | [BigQuery](https://github.com/terraform-google-modules/terraform-google-bigquery/tree/v10.2.1) | 10.2.1 |

Fabric is published by GoogleCloudPlatform and supplies the required scanning control alongside immutable tags, cleanup and repository-scoped IAM. The alternative GoogleCloudPlatform Artifact Registry 0.8.2 module did not expose scanning configuration. No upstream repository is vendored. The Fabric source uses the official archive URL at the same full commit. Terraform Stacks 1.16.3 fails to checksum an unrelated directory symlink in the Git package; the archive source initializes correctly. The selected module’s six Terraform files were compared byte-for-byte with that commit’s Git checkout.

Local exceptions are [billing-budget](../../modules/gcp/billing-budget/README.md), which preserves a deletion guard with currency and mixed thresholds, and [storage-service-agent](../../modules/gcp/storage-service-agent/README.md), which initializes the GCS identity before encryption grants. Their READMEs record the precise gaps and rejected alternatives. Runtime composition has its own documented scope.

## Private inputs and feature selection

Supply `target`, `federation` and an ephemeral sensitive `identity_token` through reviewed private deployment configuration. `target` supplies the existing project, region, shared name/labels and network allocations. Network creation is the baseline; NAT and flow logging are explicit choices.

Other capabilities use empty maps by default: `registries`, `reserved_addresses`, `workload_identities`, `kms_keyrings`, `storage_buckets`, `sql_instances`, `secret_containers`, `billing_datasets` and `billing_budgets`. `gke` and `sql_private_service_access` default to null. Choose resource names uniquely within their real cloud scope; map keys are stable logical identities, not permission to duplicate an existing resource. Removing a previously deployed entry requests its destruction and needs a private lifecycle review.

- GKE requires explicit zones, machine/disk sizing, pool counts and maintenance time. Counts and autoscaling bounds are per zone. It uses private nodes and a private control-plane endpoint, a dedicated node service account, Workload Identity and shielded nodes. CSI, CMEK, observability and maintenance options are typed inputs.
- NAT is subnet-scoped and can use a reserved outbound address. Private Google access without NAT does not supply internet egress for external models or registries. NAT itself is not a destination allowlist. Reserved public addresses do not create ingress resources.
- Workload identities create Google accounts, explicit project roles and optional Kubernetes impersonation grants. Product/runtime delivery owns Kubernetes service accounts and their annotations. This Stack does not create those accounts in Kubernetes.
- Data consumers select either an owned KMS key by logical keyring/key or one external key reference. Configure key-level principals explicitly. SQL, Secret Manager and Storage service identities are initialized before the corresponding grants; externally owned keys retain their own IAM owner. Core GKE and registry encryption references require keys and grants established independently before creation.
- SQL requires `sql_private_service_access` whenever `sql_instances` is nonempty. PostgreSQL uses private networking, TLS, backups/PITR and both Terraform/API deletion protection. It creates explicit databases and IAM users, with no default password user. IAM-user creation does not grant IAM login/proxy roles or PostgreSQL privileges; select cloud roles explicitly and keep SQL grants with product/bootstrap ownership. Password provisioning, rotation and product schema scripts remain separate owners.
- Buckets enforce uniform access and public access prevention; versioning defaults on and forced content deletion defaults off. Lifecycle rules are explicit. Secret Manager creates containers and accessor grants, never secret payload versions.
- Billing datasets prepare a destination plus reader/query permissions. They do not enable Cloud Billing export or create its tables. Budget alerts do not cap spending.

API activation is feature-selected and is preserved on destroy. There must be exactly one API owner for a project. Do not instantiate this Stack twice against one project without first separating shared foundation ownership. Additive IAM avoids replacing complete role policies; callers still must prevent two components or Stacks from owning the same role/member grant.

## Prerequisites and limits

Bootstrap the existing project, Service Usage API and narrow HCP Workload Identity Federation trust before this Stack. Use distinct plan/apply identities with the correct audience and phase restrictions. Provider configuration is explicit; the Kubernetes provider required by the GKE module has no resources enabled and is not used for runtime operations.

The runner for `agent-runtime` needs private cluster connectivity and explicit cluster identity. The public deployment files intentionally contain no deployment instances. Private input loading, a pinned target snapshot across plan/apply, cross-Stack output wiring, token exchange, lock recovery and cloud permissions remain acceptance work.

Module replacement changes Terraform addresses and some names/defaults. In particular, upstream Address has no `prevent_destroy`, SQL's allocation name follows the upstream module, and broad internal firewall rules and the scanning-controller project grant from Chat are not included. Review these differences in the private adoption plan; source validation cannot prove a no-replacement migration.

## Validation

Run `make terraform-check` and `make stacks-check` from the repository root. The first validates narrow local modules and their meaningful mock cases; the second initializes and validates both actual Stacks. Remote module interfaces are checked by Stack validation, not by forwarding wrappers. Provider locks cover selected packages; pin module sources separately and review execution-platform checksums before release.

No real plan, apply or ownership transfer is part of source validation. Acceptance against existing infrastructure requires the separate private procedure in the migration guide.
