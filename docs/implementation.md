# Implementation plan

## Current increment: contracts and OIDC bootstrap source

Implemented locally: four reference-only JSON contracts, strict Go validation, exact-byte configuration snapshot verification, phase-scoped HCP trust modules, and GCP/AWS/Azure bootstrap roots. Provider-specific private snapshot retrieval, operational HCP Stacks and cloud token exchange remain unimplemented/unverified. This is not a deployed multi-cloud platform.

## Maintainer decision: GitHub CI deferred

On 2026-09-10 the maintainer instructed us to continue without GitHub CI, preserving the existing workflow files. CI is not the current implementation blocker. Do not delete or modify the workflows merely to bypass their earlier failure. Use local validation evidence and skip workflow execution for these development commits. Do not claim the deferred checks passed.

The next PR is based on the unmerged foundation branch; neither it nor the foundation is automatically merged. License selection, repository settings and release governance remain separate tasks, not an excuse to stop contract/bootstrap implementation.

## Capability state

| Capability | State | Evidence boundary |
|---|---|---|
| Repository guard and Go CLI | Implemented; locally tested | No complete history/secret audit claimed |
| Environment/workload/release/secret contracts | Implemented; locally tested | Alpha vocabulary; no runtime provisioning |
| Snapshot checksum verification | Implemented; locally tested | No fetching, manifest authentication or HCP binding |
| HCP phase-subject and GCP/AWS/Azure trust source | Implemented source | Terraform tests authored; CLI/provider and live verification pending |
| HCP Stack configuration injection | Planned | Prove pinned inputs across plan/apply privately |
| Cloud Run / ECS / Container Apps runtimes and delivery | Planned | Implement only after configuration and auth acceptance |
| Cloudflare and administrative MCP | Planned | Independent identity/authorization boundary |
| Network/data/Kubernetes/Chat migration | Planned | Opt-in costs and separately approved state ownership |

## Next acceptance boundary

Resolve actual private HCP input wiring and phase-aware provider selection, install/pin the Terraform toolchain and verify the authored modules with mock tests. Then approve a disposable target, attach minimal scoped permissions and run positive/negative token-exchange tests in all three clouds. Only then implement the first GCP Cloud Run + Cloudflare deployment.

Every target needs a privately recorded region, resource inventory, cost estimate, spending alerts and teardown plan. Nothing in this increment authorizes creating resources or migrating live Chat state. Keep all real identifiers, outputs, plans and authentication evidence private.

## Azure acceptance slice

Added source: two Azure environment examples, a provider-neutral versioned secret reference, exhaustive provider/runtime validation tests, Azure inventory/credential guard rules, a classic Azure bootstrap root and a reusable phase-identity module. Five Azure Terraform mock test runs are authored but not executed. AzureRM is pinned to 5.5.0 in the root; the module accepts the tested-source major range. No provider binary/schema validation or cloud token exchange has run.

Next: validate the root and mock tests with the installed toolchain; privately verify exact issuer/audience/subject exchange, wrong tenant/subscription/phase denial, identity removal/disable behavior and narrowly scoped permissions. Only then implement ACR, Container Apps and delivery. AKS, network/data/Key Vault, Blob snapshot retrieval and Azure MCP adapters are planned, not implemented. Adding vocabulary is not proof of runtime support. No cloud state or existing product infrastructure has changed.
