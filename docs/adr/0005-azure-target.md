# ADR 0005: Azure is a first-class provider, not a compatibility shim

Status: requested by the maintainer; source increment available, Terraform/cloud acceptance pending.

## Decision

Extend the same public YourOwn Platform repository to GCP, AWS and Azure, with Cloudflare as the shared edge/admin integration. Keep products and real deployment inventory outside the core. Add `azure` to Environment with `container-apps` and `aks` as distinct runtime values. Existing workload, release and secret-reference contracts remain provider-neutral. Accepting a runtime name does not implement that runtime.

Use Azure user-assigned managed identities, one for each HCP plan/apply phase, with exact issuer, audience and subject. No Entra application client secret or directory-wide application-management permission is needed by this chosen source design. AzureRM 5.5.0 federated credentials use `user_assigned_identity_id`; copying the old v4 `parent_id` argument would be incorrect. The root is pinned; the actual provider schema still needs CLI verification.

The module grants no Azure RBAC or Key Vault rights. Add capability-specific permissions at the narrowest reviewed scope later. The bootstrap operator and private state backend require independently approved access. Normal HCP provider authentication and phase selection are not implemented by creating the trust resources.

## Explicit limitations

Exact HCP subjects are name-based. Azure credentials in this design do not additionally enforce an immutable HCP Stack ID; prevent name reuse and review federation when deleting/recreating targets. `disabled = true` removes federated credentials while retaining protected identities; already issued access tokens may remain effective. This switch is not instant revocation.

Tenant/subscription/client/principal GUIDs, origins, vault and registry names, Blob coordinates, tokens and real plans/state remain private. `sensitive` outputs do not remove values from state. The guard flags literal GUIDs and selected Azure endpoint/credential patterns without printing matched values, but cannot guarantee detection of all secret formats or encoded data.

Container Apps, AKS, ACR, Key Vault, data/network, Azure delivery and MCP are tracked as separate planned capabilities. Do not force paid networks, Kubernetes or a managed database into the baseline. Existing GCP/AWS inputs and workflows remain compatible; GitHub CI stays deferred.

## Sources checked for this increment

- https://developer.hashicorp.com/terraform/language/stacks/deploy/authenticate
- https://developer.hashicorp.com/terraform/language/block/stack/tfdeploy/identity_token
- https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-user-assigned-managed-identity
- https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.5.0/website/docs/r/federated_identity_credential.html.markdown
- https://github.com/hashicorp/terraform-provider-azurerm/releases/tag/v5.5.0
