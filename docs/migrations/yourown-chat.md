# Common capability migration from yourown-chat

Scope selected by the maintainer: transfer shared capabilities into universal components; keep product configuration in Chat. The reference is `yourown-chat/terraform/platform-gcp`. Its working-tree source was inspected on 2026-09-22 with repository HEAD `951723362f5cbfbdebe32cb2b51a4a37dc69ebfb`; that revision is a provenance marker, not a claim that every working-tree file matched HEAD. No source deployment values, Git history or state were copied.

## Capability mapping

The source composition had 29 active components, including repeated workload identities and registries. Their common behavior is represented through optional maps with stable logical keys, rather than one platform component for each Chat service.

| Reference capability | Platform owner | Scope and differences |
| --- | --- | --- |
| API activation | platform-gcp / Project Factory project_services | Feature-selected APIs and service identities; preserve APIs on destroy |
| VPC, ranges, NAT and reservations | platform-gcp / Network, Cloud NAT, Address | Explicit private allocations and optional egress; broad internal firewall is not copied; Address has no resource deletion guard |
| GKE and node identity | platform-gcp / private-cluster, Service Accounts | Optional private cluster, explicitly sized pools, autoscaling, labels/taints, CSI, CMEK and observability |
| Repeated workload identities | platform-gcp / Service Accounts, additive IAM | Typed account/role/namespace references; Kubernetes accounts and annotations have a separate delivery owner |
| Repeated container registries | platform-gcp / Fabric Artifact Registry | Optional map; immutable tags, CMEK, scanning choice, dry-run cleanup and scoped IAM; no scanning-controller project role |
| KMS | platform-gcp / KMS, additive key IAM | Protected symmetric keys and explicit principals; service identities initialized before grants |
| Buckets | platform-gcp / Cloud Storage | Uniform private access, versioning, lifecycle and CMEK; no S3 adapter credentials |
| Cloud SQL | platform-gcp / SQL DB private_service_access and postgresql | Private TLS, backups/PITR, database and IAM-user inputs, deletion protection; no default password user or Studio scripts |
| Secret infrastructure | platform-gcp / Secret Manager, additive IAM | Containers, replication/CMEK and access grants only; payload provisioning retains a separate owner |
| Billing export prerequisites | platform-gcp / BigQuery, additive IAM | Destination and query grants; export activation and billing-generated tables are not implemented |
| Monthly budget | platform-gcp / narrow billing-budget module | Project filter, currency, mixed actual/forecast alerts and prevent_destroy; alerts do not enforce a spending cap |
| GKE authentication | agent-runtime / GKE auth | Private endpoint and explicit short-lived credentials |
| Gateway API and agentgateway | agent-runtime / narrow runtime modules | Official pinned artifacts, namespace/RBAC ordering and separate CRD/controller ownership; product routes remain external |
| Temporal | agent-runtime / narrow runtime module | Official pinned chart/images, capacity/network policy, existing credentials/CA references and verified database TLS identity |

Exact upstream revisions, module comparison and local exceptions are in the [GCP Stack guide](../../terraform/stacks/platform-gcp/README.md) and [runtime Stack guide](../../terraform/stacks/agent-runtime/README.md). Terraform downloads official dependencies; the repository does not vendor them. Runtime policy/value composition is adapted from the maintainer's reference. No root license file was present in the inspected Chat checkout; this authorized transfer does not assign a new license to that source. A platform release still needs the maintainer's license decision.

## Product behavior retained in Chat

Chat owns concrete project/account/network bindings, service and namespace names, deployment sizing and release inventory. Studio SQL and permissions, bootstrap user password, password rotation/adoption procedures, application schemas, S3 adapter secrets, product-specific database users, routes and build publishing remain there. The shared platform exposes infrastructure and secret-reference interfaces; it does not reproduce product initialization.

kagent/Substrate deployment is not implemented by this transfer. The selected fork APIs and releases still need their own integration and acceptance work. Runtime and cloud source validation are not proof of compatibility with every existing Chat deployment.

## Future live ownership transfer

Source migration is complete independently of state migration. The source project has not been modified and still owns its live resources.

Before adoption, record each resource's current/proposed owner and state, provider/module version, Terraform address, remote name, dependencies, backup and rollback privately. Compare the existing state with the new upstream addresses. Review lifecycle changes explicitly, including Address deletion protection, upstream private allocation names, SQL user ownership and stricter runtime TLS. KMS key order in an existing upstream key list must remain stable. Confirm there is no second Gateway API/CRD owner or duplicate IAM member grant.

Use a private plan to distinguish an address move/import from a remote replacement; source similarity does not establish a safe move. Prevent concurrent applies, retain the original owner until the handoff is approved, and transfer one owner at a time. Never import the same live resource into a new active Stack while the old Stack still manages it. Do not copy historical `moved`, `removed` or `import` blocks without reviewing the actual state they address.

No real plan, apply, import, credential rotation or resource ownership transfer has been performed by this work.
