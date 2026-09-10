# YourOwn Platform

Shared infrastructure core for all YourOwn projects on Google Cloud and AWS, with Cloudflare and administrative MCP integrations.

**Status: repository foundation, not a deployed cloud platform.** GCP/AWS modules, actual HCP Stacks, Cloudflare resources and MCP servers are planned work. No credentials or cloud account are required to run the current checks.

## Scope

This repository owns reusable infrastructure code, deployment contracts, security policies and platform operations tooling. Product backends, iOS applications, business logic and application database migrations remain in their product repositories.

One public codebase does not mean one cloud account, network, database, identity or Terraform state. Each durable resource must have exactly one owner.

## Start here

- [Implementation plan](docs/implementation.md)
- [Architecture decisions](docs/adr/0001-platform-boundaries.md)
- [Private configuration and state](docs/adr/0002-private-configuration.md)
- [CI and resource ownership](docs/adr/0003-delivery-ownership.md)
- [Agent instructions](AGENTS.md)
- [Security policy](SECURITY.md)

## Local checks

Use the pinned Go toolchain from `.go-version` for CI-equivalent validation. The module retains a Go 1.23 language floor; that is not a recommendation to use an old toolchain in production.

```sh
make check
```

`platformctl scan --root .` checks **tracked working-tree files**. Stage new files before scanning. It reports rule names and locations, never matched values. Gitleaks is a separate CI gate for secret detection. Neither scanner guarantees that every possible secret or deployment identifier will be found. Git history is covered separately by Gitleaks; the inventory guard currently checks the working tree only.

## Layout

```text
terraform/    bootstrap, provider modules and HCP Stacks
runtime/      reusable Kubernetes/edge runtime components
delivery/     cloud CI/CD templates and release ownership
mcp/          administrative integration contracts and policies
contracts/    public interfaces, not deployed configuration
policies/     repository and infrastructure policy specifications
tools/        first-party Go tooling
internal/     implementations and tests for first-party Go tooling
docs/         decisions, implementation plan and migration runbooks
examples/     synthetic configurations only
```

Empty capability areas contain an explicit status document rather than fake resources or untested deployment examples. Follow the implementation plan before adding a provider.

## Licensing

The source is public. An explicit open-source license is a maintainer decision before the first release. No existing repository history or third-party implementation has been copied into this foundation.
