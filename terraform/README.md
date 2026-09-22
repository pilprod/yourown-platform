# Terraform capabilities

Two source Stacks separate cloud resources from in-cluster runtime ownership:

- [platform-gcp](stacks/platform-gcp/README.md): network and opt-in GKE, registries, workload identities, KMS, storage, PostgreSQL, secret containers and billing prerequisites.
- [agent-runtime](stacks/agent-runtime/README.md): existing-cluster authentication, Gateway API, agentgateway and Temporal.

Cloud components use pinned official Google modules directly. The [GCP module directory](modules/gcp/README.md) contains only documented gaps. Runtime modules compose official release artifacts with namespace, RBAC, TLS and network policy. kagent/Substrate installation, private deployment binding and cloud acceptance remain outstanding.

Read [agent rules](../rag/rules/terraform.md) and the [context index](../rag/knowledge/terraform.md) before Terraform work. The [Chat migration guide](../docs/migrations/yourown-chat.md) records the transferred capabilities and product boundary.

Run `make terraform-check` for local modules and `make stacks-check` for the actual Stack configurations. These require network access to pinned dependencies and provider binaries, but no cloud credentials. Commit reviewed provider locks; module releases and Git commits remain pinned separately. The public deployment files contain no deployment instances.

Bootstrap roots for trust/private state, AWS and Cloudflare implementation are [planned capabilities](../docs/implementation.md#planned-capability-boundaries). Add their directories when implementation starts.
