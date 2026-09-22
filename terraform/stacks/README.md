# Terraform Stacks

| Stack | Resource ownership |
| --- | --- |
| [platform-gcp](platform-gcp/README.md) | One target project's API activation, network and selected cloud capabilities |
| [agent-runtime](agent-runtime/README.md) | Selected namespaces, runtime policies, CRDs and Helm releases on an existing GKE cluster |

Private configuration supplies target values and phase-scoped identity tokens. Public deployment files declare no instances. Source validation does not prove private input injection, provider authentication or cloud readiness. Bootstrap trust and cross-Stack handoff belong to the private deployment integration.

Use one API owner per project, one owner per resource and a separately approved state-transfer procedure for existing infrastructure. See the [migration guide](../../docs/migrations/yourown-chat.md).
