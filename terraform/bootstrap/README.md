# Private OIDC bootstrap

Implemented source: classic Terraform roots for GCP and AWS, reusable trust modules and phase-specific HCP subject construction. These roots are NOT HCP Stacks. They establish the trust needed before real Stack deployments can authenticate.

## Safety and ownership

Run only after explicit approval of a disposable target and private backend. Public GitHub CI is deferred and unchanged; no workflow runs Terraform. Bootstrap uses an approved short-lived operator session, not keys checked into source. Keep backend files, tfvars, plans, state, command logs and resolved outputs outside the public worktree. Shell history and Terraform debug logs also require care.

Both roots have explicit remote backend blocks: GCS for GCP and S3 with native lockfiles for AWS. The private buckets must already exist and have verified encryption, access controls, versioning/retention and locking permissions. Backend provisioning is not silently handled with a temporary local state. Do not put access tokens in backend configuration; use the credential chain.

The GCP project must already exist. Service Usage must be available to the bootstrap operator. The root enables IAM, IAM Credentials, STS and Resource Manager APIs without disabling them on destroy. The operator needs reviewed permissions to enable services and create/manage the selected identities; the newly created identities cannot bootstrap their own permissions.

AWS additionally checks the expected account through `allowed_account_ids`. Select either explicit creation of the account's HCP OIDC provider or reuse its ARN. A provider has one account-level owner; do not recreate it per Stack. The first owner retains its state while subsequent Stack-role modules consume its private ARN.

## Trust, not blanket authorization

The shared subject module constrains organization, project, Stack, deployment and operation using exact values. The only operations are plan and apply. Names containing wildcard/delimiter characters are rejected. Full subjects must fit HCP's documented length limit.

GCP checks issuer, audience, exact subject and immutable Stack ID. Each phase may impersonate only its matching service account through an additive Workload Identity User binding. AWS uses StringEquals for audience and exact subject; custom HCP Stack-ID claims are not assumed usable as arbitrary IAM OIDC condition keys. Name reuse and target deletion require an explicit trust review/revocation.

The roles/service accounts receive NO project, infrastructure or secret-reading permissions here. Grant the minimal resource-scoped read/config permissions for plan and reviewed mutation permissions for apply in the owning bootstrap extension. No Owner, Editor, AdministratorAccess or wildcard resource policy is a default.

`disabled = true` blocks new federation/assumption. Previously issued access tokens/STS sessions can remain valid; incident response must separately address them and remove effective permissions where needed. Identity deletion is guarded with `prevent_destroy`; teardown requires a reviewed ownership and revocation change, not a blind destroy.

## Private execution outline

```sh
# Paths and credentials are configured privately by the operator.
terraform -chdir=terraform/bootstrap/gcp init -backend-config="$PRIVATE_GCP_BACKEND"
terraform -chdir=terraform/bootstrap/gcp plan -var-file="$PRIVATE_GCP_INPUTS" -out="$PRIVATE_GCP_PLAN"
# Apply the exact approved saved plan only after review.
terraform -chdir=terraform/bootstrap/gcp apply "$PRIVATE_GCP_PLAN"
```

Use the analogous AWS root with its own backend, inputs and saved plan. Do not reuse bootstrap permissions as normal runtime permissions. Required inputs are declared in each root; no live values or tfvars examples are published.

## Local Terraform validation, still to be executed

```sh
for directory in \
  terraform/modules/hcp/stack-subjects \
  terraform/modules/gcp/stack-identity \
  terraform/modules/aws/stack-identity; do
  terraform -chdir="$directory" init -backend=false
  terraform -chdir="$directory" validate
  terraform -chdir="$directory" test
 done
terraform fmt -check -recursive terraform
```

The provider tests use mocks, not real credentials. Module subject tests include wildcard/delimiter/length rejection; provider tests inspect phase separation, issuer/audience restrictions and disable behavior. They do not prove real token exchange or live IAM denial. Root init/validate also needs provider installation and must not accidentally initialize a real backend during static checks.

Root provider selections are pinned to google 8.2.0 and aws 6.64.0, verified against upstream releases on 2026-09-10. Generate and review the dependency lockfiles with the real CLI/provider registry before private use; no fabricated checksum lockfile is included. The CLI floor is Terraform 1.10 for the S3 lockfile and validation features. Select and record the actual engine version before HCP acceptance.

## Still required before cloud-tested status

Configure the real private HCP Stack and runtime provider authentication. Select the correct plan/apply identity for each operation; any decoding of a token for routing is not signature verification or authorization. The cloud provider must validate its signature and claims. Provider selection, ephemeral inputs and private configuration readers are not implemented by these bootstrap roots.

Test successful token exchange, wrong audience, wrong Stack/deployment, wrong phase and denied resource access. Record sanitized results only. Neither provider is marked cloud-tested in this increment, and no existing Chat state is migrated.

References:
- https://developer.hashicorp.com/terraform/language/block/stack/tfdeploy/identity_token
- https://developer.hashicorp.com/terraform/language/block/stack/tfdeploy/store
- https://developer.hashicorp.com/terraform/language/backend/s3
- https://github.com/hashicorp/terraform-provider-google/releases/tag/v8.2.0
- https://github.com/hashicorp/terraform-provider-aws/releases/tag/v6.64.0

## Azure extension

The same trust-first scope now includes `bootstrap/azure` and `modules/azure/stack-identity`. Follow the [Azure runbook](azure/README.md): this root uses private Azure Blob state with Entra authentication, a separate identity resource group, explicit tenant/subscription binding and user-assigned identities for each HCP phase. No roles are granted by default. Include the Azure module in the local mock-test loop above. Azure has five additional authored test runs, not executed. The Azure root pins AzureRM 5.5.0; do not apply v4 resource argument examples to it without checking the v5 schema.
