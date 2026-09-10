# YourOwn Platform

Shared infrastructure core for all YourOwn projects on Google Cloud, AWS and Microsoft Azure, with Cloudflare and administrative MCP integrations.

**Status: contracts and OIDC bootstrap source, not a deployed cloud platform.** Reference contracts and Go tooling are locally tested. GCP/AWS/Azure trust modules and bootstrap roots are implemented source with Terraform/cloud validation pending; operational HCP Stacks, runtimes, Cloudflare and MCP remain planned. No cloud credentials are required for the Go checks.

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

`platformctl scan --root .` checks **tracked working-tree files**. Stage new files before scanning. It reports rule names and locations, never matched values. Gitleaks is configured as a separate, currently deferred CI check for secret detection. Neither scanner guarantees that every possible secret or deployment identifier will be found. History scanning is configured separately through Gitleaks but has not been executed for this increment; the inventory guard currently checks the working tree only.

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

Empty capability areas contain an explicit status document rather than fake resources or untested deployment examples. Follow the implementation plan before adding a capability.

## Licensing

The source is public. An explicit open-source license is a maintainer decision before the first release. No existing repository history or third-party implementation has been copied into this foundation.

## Second increment: reference contracts and bootstrap source

See [contracts](contracts/README.md) for the implemented Go commands and [OIDC bootstrap](terraform/bootstrap/README.md) for GCP/AWS roots and the [Azure runbook](terraform/bootstrap/azure/README.md) for the Azure root and authored Terraform tests. None of the three clouds has been provisioned or accepted. GitHub CI is deferred by maintainer instruction; its workflow files are retained unchanged. The current source/evidence distinction is tracked in [implementation status](docs/implementation.md).

## Azure extension

Azure is a first-class target, not an alias for AWS or GCP. The contract vocabulary now accepts `azure + container-apps` and `azure + aks`. Azure trust/bootstrap source creates separate phase identities; it does not deploy Container Apps, AKS, ACR, Key Vault or Azure Pipelines. See [Azure capabilities](terraform/modules/azure/README.md) and [ADR 0005](docs/adr/0005-azure-target.md). Real tenant, subscription, client IDs and service endpoints stay private. GitHub workflows remain unchanged and deferred.
