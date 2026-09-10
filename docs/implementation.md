# Implementation plan

## Current increment: repository foundation

Reviewable source, instructions, architecture decisions, a working Go repository guard with tests, and credential-free CI. This is not an implemented multi-cloud runtime. The initial README commit only initializes the repository; substantive work is reviewed separately.

## Ordered backlog

| Phase | Deliverable | Acceptance boundary |
|---|---|---|
| P0 | Foundation review and governance | Local checks pass; public CI verified; maintainer configures protections and chooses license |
| P1 | Private configuration and HCP Stacks contract | Pin inputs per run; demonstrate plan/apply stability and no public inventory leakage |
| P1 | GCP/AWS OIDC bootstrap | Distinct scoped identities; valid target succeeds; wrong target/audience fails; no static cloud key |
| P1 | GCP Cloud Run vertical slice | Two isolated targets; deploy immutable digest; unauthorized service calls denied; rollback proven |
| P1 | Cloudflare edge and admin boundaries | No origin bypass without an authenticated policy; MCP streaming works; no product-to-admin privilege path |
| P1 | Read-only platform MCP | Authorized inventory/status only; target isolation; no raw secret/plan disclosure or mutation tool |
| P2 | AWS workload delivery | ECS semantics explicit; same public contract where meaningful; networking and idle costs measured |
| P2 | Kubernetes profiles and Chat migration | GKE/EKS modules tested; one reconciler; ownership transfer without duplicate management |

A task is done only with the evidence stated in its linked GitHub issue. Static validation is not a cloud acceptance test. Architecture decisions are proposed until reviewed.

## Cost and safety gates

No cloud resource is created by this foundation. Before provisioning, record selected region, resource inventory, recurring cost estimate, spending alerts and teardown procedure privately. Do not assume HCP Stacks, NAT, load balancers, clusters or HA databases are free.

## First cloud acceptance slice

Provision a disposable GCP target and one container service from a pinned digest, with a second private IAM-protected service, through reviewed HCP Stacks and private configuration. Attach a separately authenticated Cloudflare edge, test direct-origin requests, revoke an identity, update the image, roll back, and tear down. Repeat in a second target without editing reusable modules or committing live identifiers.

AWS bootstrap is developed in the same foundation phase. AWS application runtime and Kubernetes are separate acceptance slices rather than a promise of feature parity on day one.
