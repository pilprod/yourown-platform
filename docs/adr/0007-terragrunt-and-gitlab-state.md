# ADR 0007: Terragrunt Stacks and private GitLab state

Status: selected by the maintainer on 2026-09-24; deployment acceptance pending.

## Decision

Use Terragrunt Stacks for new platform cloud composition, starting with Azure AKS, Key Vault and customer-managed encryption keys. Retain the repository's pinned Terraform engine; this decision does not switch to OpenTofu. GitLab is the primary source host; public repositories are mirrored to GitHub. A separate private GitLab.com project stores state through Terraform's HTTP backend. GitHub mirrors do not run deployment workflows.

This supersedes the HCP-only composition and execution direction in ADRs 0001–0005 for new work. It preserves upstream reuse, private configuration and singular resource ownership. The existing `terraform/stacks/platform-gcp` and `terraform/stacks/agent-runtime` HCP sources remain legacy compositions with their current interfaces, locks and owners. They have not been converted, deployed or adopted into new state by this decision.

## Composition and configuration

An explicit `terragrunt.stack.hcl` assembles reusable units and their dependencies. Azure units consume pinned Azure Verified Modules directly wherever suitable. Terragrunt owns the composition and generated provider/backend wiring; upstream modules own their resource implementation. A local wrapper still needs a specific unsupported capability, not merely forwarded inputs. Pin Git sources to full commits and registry sources to exact releases; review provider locks separately.

Public source lives under `terragrunt/azure/`: shared wiring in `root.hcl`, the Azure stack under `stacks/azure-aks/`, and reusable units under `units/`. Keep target subscription/tenant, allocated networks, names, access bindings and state project selection in private environment configuration. Consume a fixed configuration snapshot for each reviewed plan/apply. Generated stacks, caches, backend configuration, plans and live outputs are private execution artifacts.

## State contract

Each Terraform unit has a distinct, stable state identifier within the private GitLab project. Choose identifiers explicitly from the environment and logical unit identity; do not derive them from a checkout path, branch, cache path or generated directory. The Azure stack supplies `values.state_suffix` explicitly for each unit, and `root.hcl` combines it with the private environment's `state_prefix`. Renaming a directory while preserving that suffix must not silently select empty state. Changing a state identifier or backend for existing resources requires a reviewed migration, backup and rollback.

Use the GitLab.com endpoint `/api/v4/projects/<project-id>/terraform/state/<state-id>`. Configure locking explicitly: `POST` to the state's `/lock` endpoint, and `DELETE` to that same endpoint to unlock. These are GitLab's methods rather than the HTTP backend's generic locking defaults. Keep locking enabled and preserve TLS verification. A state reader can see sensitive state, so private-project access is privileged even for read-only planning.

Supply backend credentials only through `TF_HTTP_USERNAME` and `TF_HTTP_PASSWORD` in the execution environment. Never embed them in HCL, generated backend files, command-line `-backend-config` arguments or plans. Azure authentication is separately scoped and also remains outside public source. An authenticated CLI session is not evidence that GitLab access, target permissions, credit, quotas or the deployment itself have been accepted.

## Delivery and existing ownership

Public validation and GitHub mirrors run without cloud credentials. ADR 0008 supersedes the earlier private-execution-only restriction: trusted protected-branch jobs may run in the existing public GitLab project, with restricted logs/artifacts, protected private inputs, OIDC trust and explicit plan approval before apply. GitLab cloud CI is not configured yet.

The desired integration is Gruntwork Pipelines running in GitLab CI, using separate Entra OIDC identities for plan and apply. Official documentation supports this manual GitLab/Azure setup; the Developer Portal wizard is not evidence of a connected subscription. This integration is not configured. Availability of GitLab/Azure on the selected Terragrunt Scale Free account and compatibility of the complete Pipelines workflow with the existing GitLab HTTP backend remain to be verified. The upstream Azure bootstrap template uses Azure Blob state; adopting Pipelines does not authorize changing this repository's backend or migrating state.

Terraform owns cloud infrastructure. Flux is the selected separate GitOps process for the new in-cluster platform runtime; product values and agent definitions remain in their owning repositories. Do not apply the existing GKE-specific `agent-runtime` Stack to AKS or install resources already reconciled by Flux. Any future migration of existing CRDs, releases or cloud resources must transfer one owner at a time with explicit state and rollback evidence.

## Acceptance

Validate Terragrunt stack generation and unit configuration with the chosen Terraform toolchain without ambient cloud credentials. Keep the existing HCP Stack checks for their retained source. Static validation does not prove GitLab locking, Azure permissions, Key Vault access or Kubernetes readiness.

Before a real deployment, verify the private GitLab project and backend access, selected Azure subscription/credit expiry, region/SKU quotas, resource inventory, cost estimate and teardown plan. Review the actual private plan. Verify backend lock behavior and cloud resource health on the authorized target, then perform Flux runtime acceptance separately. No existing state migration is implied.

## References

- [Terragrunt Stacks](https://docs.terragrunt.com/features/stacks/).
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/indexes/terraform/).
- [GitLab-managed Terraform/OpenTofu state](https://docs.gitlab.com/user/infrastructure/iac/terraform_state/).
- [Terraform HTTP backend](https://developer.hashicorp.com/terraform/language/backend/http).
- [Gruntwork Pipelines architecture](https://docs.gruntwork.io/2.0/docs/pipelines/architecture/).
- [Pipelines in an existing GitLab project](https://docs.gruntwork.io/2.0/docs/pipelines/installation/addingexistinggitlabrepo/).
- [Pipelines Azure OIDC](https://docs.gruntwork.io/2.0/docs/pipelines/concepts/cloud-auth/azure/).
- [Terragrunt Scale plans](https://terragrunt.com/terragrunt-scale) and [Free tier launch scope](https://www.gruntwork.io/changelog/terragrunt-scale-free-tier-up-to-25-units).
