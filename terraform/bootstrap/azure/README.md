# Azure HCP federation bootstrap

Status: implemented source and five authored module mock-test runs. Terraform CLI/provider validation and real HCP/Azure token exchange have NOT run. This is not an operational Stack or Azure workload deployment.

## Prerequisites and ownership

An approved subscription/tenant and a private Azure Blob backend must already exist. Supply backend account/container/key and target bindings privately. Use Entra authentication (`use_azuread_auth = true`), not storage account keys or SAS. Verify state access, lease locking, retention, recovery and storage network reachability before initialization; the root does not create its own backend or fall back to local state.

The operator uses an approved short-lived authenticated session, independently of the identities being created. Scope permissions to creation of the identity resource group, user-assigned identities and federated credentials; no blanket subscription Owner role is required by policy. Pre-register Microsoft.ManagedIdentity through its approved subscription owner. Automatic resource-provider registration is disabled. Backend data access and Azure resource-management permissions are separate grants.

This root owns one dedicated identity resource group plus distinct `plan` and `apply` user-assigned identities. Do not use a shared production workload resource group or adopt an existing resource implicitly. Existing identities/groups require a separately reviewed import/ownership operation. Root provider configuration binds explicit private tenant/subscription IDs and checks the authenticated target before creating the group. The reusable identity module receives the provider from its caller.

## Trust contract

Federated credentials use the issuer `https://app.terraform.io`, audience `api://AzureADTokenExchange`, and the shared exact HCP organization/project/Stack/deployment/operation subject. There are no wildcard subjects and no extra immutable Stack-ID claim restriction in this Azure implementation. Name reuse requires trust review. Roles and data-plane/Key Vault rights are deliberately absent.

Set `disabled = true` through an approved private change to remove both federated credentials without deleting identities. This prevents new exchange after propagation but is not guaranteed instant revocation of already issued access tokens. Incident response must also address effective permissions and active sessions. Protected identities and resource group require an explicit retirement procedure rather than a blind destroy.

## Private operator outline

```sh
terraform -chdir=terraform/bootstrap/azure init -backend-config="$PRIVATE_AZURE_BACKEND"
terraform -chdir=terraform/bootstrap/azure plan -var-file="$PRIVATE_AZURE_INPUTS" -out="$PRIVATE_AZURE_PLAN"
# Only after reviewing the exact private saved plan:
terraform -chdir=terraform/bootstrap/azure apply "$PRIVATE_AZURE_PLAN"
```

Required private inputs: subscription_id, tenant_id, hcp names, resource_group_name, location and name_prefix. Identity outputs are sensitive references, not secret-free public inventory. Never paste inputs/outputs, state or debug logs into public issues. The root does not create a workload, network, vault, registry, pipeline or secret value.

## Static checks to execute with the real toolchain

```sh
terraform -chdir=terraform/modules/azure/stack-identity init -backend=false
terraform -chdir=terraform/modules/azure/stack-identity validate
terraform -chdir=terraform/modules/azure/stack-identity test
terraform -chdir=terraform/bootstrap/azure init -backend=false
terraform -chdir=terraform/bootstrap/azure validate
terraform fmt -check -recursive terraform
```

The root pins AzureRM 5.5.0. Its federated credential argument is `user_assigned_identity_id`, not the older `parent_id`. Generate/review actual dependency lockfiles; do not fabricate checksums. Select the Terraform engine version and validate provider schema before apply. Mock plan tests assert phase separation, exact issuer/audience/subject, disable behavior and invalid inputs; they are not real authentication or authorization tests.

## Private acceptance still required

HCP `identity_token` must use the Azure audience; the runtime AzureRM provider must select the matching phase client ID and use OIDC rather than static secrets. That Stack wiring is separate, currently unimplemented. Add minimal reviewed RBAC only after identities are accepted. Verify valid exchange, wrong tenant/subscription/audience/Stack/deployment/phase denial, disabled trust and denied resource/secret access. Verify Azure API support and federation propagation in the chosen region. Sovereign clouds and cross-tenant operation are not included in the first target.

Private configuration will use a pinned Blob version plus exact-byte checksum and approved manifest. No Blob reader or HCP plan/apply binding is implemented by this root. Keep the configuration task open.

References:
- https://developer.hashicorp.com/terraform/language/backend/azurerm
- https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-user-assigned-managed-identity
- https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.5.0/website/docs/r/federated_identity_credential.html.markdown
