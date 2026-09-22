# Implementation plan

## Current increment: agent infrastructure through Terraform Stacks

The maintainer selected kagent and agentgateway as the first runtime and Terraform
Stacks as the owner of cloud infrastructure. See [ADR 0004](adr/0004-agents-first-stacks.md).
The common capabilities from `yourown-chat/terraform/platform-gcp` now live in
[platform-gcp](../terraform/stacks/platform-gcp/README.md) and
[agent-runtime](../terraform/stacks/agent-runtime/README.md). Cloud composition
uses official Google modules directly; local code fills documented billing
protection, service-identity initialization and runtime policy gaps. The earlier
five local cloud implementations and README-only placeholder directories have
been removed. See [migration scope](migrations/yourown-chat.md).

Source checks cover local module validation/mocks, actual Stack validation,
synthetic optional-input expression checks, Go tooling and the repository guard.
Private deployment binding, cloud acceptance and kagent/Substrate release
integration remain outstanding. Agentgateway and Temporal source composition
is implemented; installation on a real cluster has not been verified.

## Local validation evidence

Checked on 2026-09-22 with Terraform 1.16.3 and Terraform Stacks plugin 1.4.0:

- Both actual Stacks initialized and validated; cloud provider locks include macOS ARM64 and Linux AMD64 packages.
- Five local modules validated; nine mock tests passed across budget scope/thresholds, release integrity, gateway capacity and Temporal TLS/network inputs.
- Pinned agentgateway and Temporal charts rendered with Helm 3.20.2 and synthetic Kubernetes 1.35 capabilities. Render inspection verified image digests, internal services, explicit RBAC bindings, existing Secret/CA references and TLS hostname checks for both Temporal servers and schema jobs. The disabled-schema render performs no database schema work, although the upstream chart retains a completion-only Job.
- Four synthetic GCP expression profiles covered disabled features, registry without a cluster, fixed pools and mixed autoscaling/CMEK inputs.
- `make check` passed: Go formatting, vet, race tests, tracked-file guard and all three RAG context bundles. Local documentation links and staged whitespace checks passed.

These checks did not authenticate to a cloud target. Private input bindings, real plans/applies, cluster readiness and ownership migration remain unverified. Public CI currently runs the Go/repository and Gitleaks gates; Terraform checks are explicit local Make targets.

## Shared development-agent context

Canonical rules and knowledge navigation live in [rag/](../rag/README.md). Native
client entry points and the local `platformctl context` bundle are implemented.
Live Claude/vLLM adapters, model behavior acceptance, embeddings and a shared
retrieval service remain unimplemented. These development-agent tools are separate from the cloud/runtime source migration and do not demonstrate model compliance or cloud deployment.

## Planned capability boundaries

These areas have no implementation directory yet. Their acceptance sequence is
listed below; adding documentation does not implement a capability.

- **Bootstrap:** separate classic roots for HCP, GCP and AWS trust and private state. Require scoped OIDC, no static cloud keys, wrong-target denial and an idempotent rerun.
- **Contracts:** environment binding, workload, immutable release, secret reference and administrative MCP capability. Public contracts use logical references; bindings, networks, origins and credentials remain private. Require JSON Schema plus negative and compatibility tests.
- **Delivery:** provider-specific build/deploy templates. Terraform owns cloud pipeline infrastructure; products own source, tests, image build context and schema migrations. Pin image digests and assign one workload revision owner.
- **Administrative MCP:** target-scoped, read-only inventory/status and Go adapters for HCP/GCP/AWS. Exclude raw state, secrets, arbitrary execution and automatic apply. Product MCP remains separate.
- **Policies:** the tracked-file repository guard and CI Gitleaks job are implemented. Terraform policy gates, Kubernetes admission baselines, target isolation and private apply approval remain planned; documentation is not enforcement.
- **AWS:** account binding, identity and private configuration first, then ECR/ECS. EKS, RDS and expensive network defaults remain opt-in.
- **Cloudflare:** separate edge and administrative access. Select origin authentication per runtime; DNS proxying alone does not close the origin.
- **Examples:** synthetic GCP serverless, AWS containers and optional Kubernetes profiles. Use no real accounts, addresses, networks, endpoints or credentials; pass the repository guard and the relevant contract validators when implemented.

## Ordered backlog

| Phase | Deliverable | Acceptance boundary |
|---|---|---|
| P0 | Foundation review and governance | Local checks pass; public CI verified; maintainer configures protections and chooses license |
| P1 | Agent infrastructure and runtime | Cloud/runtime source is implemented; bind private inputs, integrate kagent/Substrate, then verify agent lifecycle and authorized MCP traffic on an approved target |
| P1 | Private configuration and HCP Stacks contract | Pin inputs per run; demonstrate plan/apply stability and no public inventory leakage |
| P1 | GCP/AWS OIDC bootstrap | Distinct scoped identities; valid target succeeds; wrong target/audience fails; no static cloud key |
| P1 | GCP Cloud Run vertical slice | Two isolated targets; deploy immutable digest; unauthorized service calls denied; rollback proven |
| P1 | Cloudflare edge and admin boundaries | No origin bypass without an authenticated policy; MCP streaming works; no product-to-admin privilege path |
| P1 | Read-only platform MCP | Authorized inventory/status only; target isolation; no raw secret/plan disclosure or mutation tool |
| P2 | AWS workload delivery | ECS semantics explicit; same public contract where meaningful; networking and idle costs measured |
| P2 | Existing Chat resource adoption and additional Kubernetes profiles | Common GCP source transferred; review state/address mapping privately, prove one reconciler and transfer ownership without duplicate management |

A task is done only with the evidence stated in its linked GitHub issue. Static validation is not a cloud acceptance test. Architecture decisions are proposed until reviewed.

## Cost and safety gates

No cloud operation has been performed during source development. Before provisioning, record selected region, resource inventory, recurring cost estimate, spending alerts and teardown procedure privately. Do not assume HCP Stacks, NAT, load balancers, clusters or HA databases are free.

## Subsequent serverless acceptance slice

Provision a disposable GCP target and one container service from a pinned digest, with a second private IAM-protected service, through reviewed HCP Stacks and private configuration. Attach a separately authenticated Cloudflare edge, test direct-origin requests, revoke an identity, update the image, roll back, and tear down. Repeat in a second target without editing reusable modules or committing live identifiers.

AWS bootstrap is developed in the same foundation phase. AWS application runtime and Kubernetes are separate acceptance slices rather than a promise of feature parity on day one.

The earlier Cloud Run sequence remains a subsequent runtime option. For the
currently selected agent-first sequence, follow ADR 0004 and keep any existing
Chat deployment under its current resource owners.
