# YourOwn Platform

Shared infrastructure core for all YourOwn projects on Google Cloud and AWS, with Cloudflare and administrative MCP integrations.

**Status: source implementation; cloud acceptance pending.** Two Terraform Stacks compose reusable GCP capabilities and the agentgateway/Temporal runtime. Cloud resources use pinned official Google modules, with narrow documented exceptions. kagent/Substrate installation, private bootstrap/configuration, AWS, Cloudflare and MCP servers remain planned.

## Scope

This repository owns reusable infrastructure code, deployment contracts, security policies and platform operations tooling. Product backends, iOS applications, business logic and application database migrations remain in their product repositories.

One public codebase does not mean one cloud account, network, database, identity or Terraform state. Each durable resource must have exactly one owner.

## Start here

- [Implementation plan](docs/implementation.md)
- [Agents-first Terraform Stacks](docs/adr/0004-agents-first-stacks.md)
- [GCP platform infrastructure](terraform/stacks/platform-gcp/README.md)
- [Agent runtime](terraform/stacks/agent-runtime/README.md)
- [Chat migration scope](docs/migrations/yourown-chat.md)
- [Architecture decisions](docs/adr/0001-platform-boundaries.md)
- [Private configuration and state](docs/adr/0002-private-configuration.md)
- [CI and resource ownership](docs/adr/0003-delivery-ownership.md)
- [Agent instructions](AGENTS.md)
- [Shared agent rules and knowledge](rag/README.md)
- [Terraform knowledge](rag/knowledge/terraform.md)
- [Security policy](SECURITY.md)

## Local checks

Use the pinned Go toolchain from `.go-version` for CI-equivalent validation. The module retains a Go 1.23 language floor; that is not a recommendation to use an old toolchain in production.

```sh
make check
```

`platformctl scan --root .` checks **tracked working-tree files**. Stage new files before scanning. It reports rule names and locations, never matched values. Gitleaks is a separate CI gate for secret detection. Neither scanner guarantees that every possible secret or deployment identifier will be found. Git history is covered separately by Gitleaks; the inventory guard currently checks the working tree only.

## Layout

```text
terraform/    HCP Stacks and infrastructure dependency configuration
runtime/      selected agent runtime boundaries and prerequisites
rag/          shared development-agent rules, knowledge and adapters
tools/        first-party Go tooling
internal/     implementations and tests for first-party Go tooling
docs/         decisions, implementation plan and migration runbooks
```

Planned capabilities are tracked in the [implementation plan](docs/implementation.md#planned-capability-boundaries). Add a directory when its implementation begins.

## Licensing

The source is public. An explicit open-source license is a maintainer decision before the first release. Official modules and release artifacts retain their upstream licenses. Shared runtime composition is adapted from the maintainer’s Chat reference; provenance and exclusions are recorded in the migration guide. Git history and live deployment configuration are not copied.
