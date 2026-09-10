# Agent instructions

## Scope

Build the shared YourOwn Platform, not a product backend. GCP, AWS and Cloudflare are first-class integration targets. Use Go for first-party executable tools and MCP adapters. Terraform remains the infrastructure engine; do not build a replacement orchestration language.

## Non-negotiable boundaries

- Never commit credentials, real IP/CIDR literals, account/billing/project IDs, deployed origins, private inventories, state, plans, production renders or kubeconfig files.
- Do not request that an operator paste secrets into a chat, issue or PR. Use private provider stores and references.
- Public CI has no cloud credentials and must not plan or apply against real infrastructure. Do not use pull_request_target or workflow_run to execute untrusted contributions with elevated permissions.
- Pin external Actions to verified full commit SHAs. Keep public CI permissions read-only.
- Each resource has one Stack owner; document ownership transfer before moving state. Never let old and new stacks manage the same resource concurrently.
- Product users, including Clerk users, are not platform administrators.
- Administrative MCP starts read-only. No arbitrary shell/cloud API tool and no autonomous production apply. A tool annotation or prompt is not authorization.
- Do not provision resources, merge infrastructure changes, migrate state or rotate credentials without an explicitly approved operation.

## Implement incrementally

Read docs/implementation.md and the relevant ADR. Complete the smallest testable acceptance slice, not every planned directory. Mark capabilities as planned, implemented or cloud-tested. Do not claim a module is operational based only on fmt/validate.

Reusable modules have typed inputs and outputs, no embedded provider credentials, no deployment-specific defaults and no backend configuration. HCP Stack composition and bootstrap root modules own provider/state wiring. Stacks need their own validation; terraform validate on a classic module is not a Stack validation substitute.

Keep cloud semantics explicit: Cloud Run and ECS are not identical runtimes. Kubernetes, NAT, HA databases, HSM and cross-cloud networking are opt-in capabilities, not mandatory baseline costs.

## Validation and evidence

Run make check before proposing a commit; stage all intended files so the tracked-file guard sees them. Test negative cases. Never print matched sensitive values in failure output. Do not publish real plans, logs or inventories as test evidence. Record which checks ran, which were unavailable and which require private cloud acceptance.

## Existing infrastructure

Treat pilprod/yourown-chat as read-only migration input until an ownership-transfer task is approved. Copy reusable implementation only after license/provenance and privacy review. Do not copy live deployment files or Git history wholesale.
