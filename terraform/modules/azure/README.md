# Azure capabilities

Azure is a first-class platform target with explicit provider semantics. Only the identity/bootstrap source is implemented in this increment; no Azure capability is cloud-tested.

| Capability | Proposed implementation | State |
|---|---|---|
| HCP federation | User-assigned managed identities and exact federated credentials | Source and five unexecuted mock test runs |
| Bootstrap state | Entra-authenticated Azure Blob backend in classic root | Source; private backend is a prerequisite |
| Configuration | Pinned private Blob version and authenticated manifest | Planned |
| Registry/runtime | ACR and Container Apps | Planned |
| Kubernetes | AKS and workload identity | Planned; optional |
| Network | VNet/subnets/private connectivity | Planned; opt-in |
| Data/secrets | Blob Storage, Key Vault, managed PostgreSQL | Planned; opt-in |
| Delivery | Selected cloud-native build/release pipeline | Planned |
| Observability | Azure Monitor/Log Analytics with bounded retention | Planned |
| Administrative MCP | Target-scoped read-only adapter | Planned |

`stack-identity` takes HCP names, region, identity resource group and a naming prefix. Subscription and tenant selection belong in the owning provider/root, not in the reusable module. Outputs are private identity references; there are no passwords or role assignments. Read the [bootstrap runbook](../../bootstrap/azure/README.md) before using the module. Azure sovereign clouds and cross-tenant deployments are outside this initial acceptance scope.
