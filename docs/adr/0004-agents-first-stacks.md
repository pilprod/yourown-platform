# ADR 0004: Terraform Stacks with an agents-first delivery sequence

Status: implementation direction requested by the maintainer; cloud acceptance pending.

## Decision

Terraform Stacks own the platform's cloud resources. Start with the infrastructure
needed by `pilprod/kagent` and `pilprod/agentgateway`. Keep GCP, AWS and Cloudflare
implementations explicit; support for one provider does not prove another works.

This changes the implementation order in ADR 0001: the first selected runtime is
Kubernetes for the agent platform. Kubernetes remains an opt-in capability for
other workloads. Product microservices need not inherit an agent cluster.

Each Stack groups resources with one owner and lifecycle. Following
[ADR 0005](0005-reuse-upstream-terraform-modules.md), prefer suitable upstream
modules directly; local modules require a documented capability gap. Private
deployment configuration selects the target and immutable release inputs. Do not add a new deployment language or a
second controller for the same resources.

| Layer | Owns | Status |
| --- | --- | --- |
| Bootstrap | Existing project binding, private state and HCP identity trust | Planned separately |
| GCP platform | Required APIs, VPC/subnet, opt-in NAT, addresses, identities, registries and GKE | Source implemented with upstream modules |
| Shared data and billing | PostgreSQL, backups, KMS, secret containers, storage and billing prerequisites | Source implemented in platform-gcp |
| Agent runtime | Gateway API, agentgateway and Temporal | Source implemented; kagent/Substrate integration pending |
| Edge | Cloudflare origin authentication and separate operator access | Planned |
| Product/agent definitions | Product source, Harness/AgentTemplate definitions and release inputs | Independent repositories |

The cloud Stack is `terraform/stacks/platform-gcp`; runtime resources are in `terraform/stacks/agent-runtime`. It has one component
per module, explicit dependencies and no deployment-specific defaults. It does
not create a project or impersonation trust for its own provider. Private
bootstrap must establish those prerequisites before it can be applied.

## Agent runtime boundaries

The inspected kagent fork uses `Harness` and `AgentTemplate` in
`kagent.dev/v1alpha3`, PostgreSQL-backed instances and Substrate compute. It is
not compatible with generic upstream installation examples. Runtime installation
must follow the APIs and values at the selected fork commit.

Keep the source pins and built artifact digests separate. A Git commit is not
evidence that a chart/image was published or tested. The runtime slice must
select reviewed chart and image artifacts from these sources:

- [kagent source](https://github.com/pilprod/kagent/tree/547cfe605940005173eb0372238339384102faa0): inspected branch `yourown-chat`.
- [agentgateway source](https://github.com/pilprod/agentgateway/tree/748b38b25d6e8c981c42e40b5e808d84c483c1bf): inspected branch `main`.
- kagent's source Go dependency selects `pilprod/substrate v0.0.22`; the runtime
  chart/image compatibility and source provenance need their own release check.

The migrated gateway runtime currently uses the official artifacts selected by the Chat reference; compatibility with the fork pins above is still a separate acceptance check.

The runtime Stack owns Gateway API CRDs and gateway installation. Its future Substrate and kagent integration must preserve separate ownership. Do not install a second copy of a gateway or Substrate through a
subchart. Use an external database, existing secret references, explicit
namespace scope and digest-pinned images. Do not use chart demo credentials,
cluster-wide default write grants or default administrative tool packs.

Agentgateway owns MCP/A2A/model traffic policy, not cloud provisioning. Tool-list
selection in an agent definition does not replace server-side authorization.
Administrative tools and product-user agents have different identities and
access boundaries. AgentInstance state and A2A semantics remain owned by kagent.

## What the Chat reference taught us

`yourown-chat` mixes shared infrastructure, product-specific addresses, build
publishing and release selection in large compositions. Preserve the useful
resource ownership boundaries, while making inputs and dependencies explicit
in Stack composition and any justified local modules. Do not copy its live
values, moved/import blocks, defaults, history, product assets or shell deployment
machinery.

The common Chat capabilities have been generalized using official Google modules and narrow runtime composition. See the [migration scope](../migrations/yourown-chat.md) for provenance and exclusions. This source migration does not transfer any Chat resource or Terraform state. A future migration needs a resource-by-resource
ownership transfer, private plan evidence and rollback.

## Acceptance sequence

1. Validate the actual HCP Stack and its pinned dependencies. Validate justified
   local modules separately and use mocked positive/negative cases for platform
   policy where meaningful; do not introduce wrappers solely for testing.
2. Implement private pinned deployment inputs and phase-scoped identity wiring.
3. Approve a disposable target, cost, runner connectivity and teardown; verify
   the infrastructure with real credentials only there.
4. Complete kagent/Substrate artifact selection, verify pinned chart renders, then test a clean install and deterministic MCP routing through agentgateway.
5. Exercise one agent instance and A2A interaction, negative authorization,
   restart/recovery and rollback. Only then mark the runtime cloud-tested.

These are separate acceptance gates. Static validation does not prove agents
run or that cloud networking and authorization work.
