# Agent runtime

The [agent-runtime Stack](../terraform/stacks/agent-runtime/README.md) contains reusable agentgateway and Temporal source configuration for an existing private GKE cluster. It uses official Helm charts, explicit capacity and namespace inputs, and existing database Secret references. Cloud infrastructure belongs to [platform-gcp](../terraform/stacks/platform-gcp/README.md). Neither Stack has a public deployment binding or completed cloud acceptance.

The selected first agent execution runtime remains the maintainer's kagent and agentgateway forks, with Substrate and PostgreSQL prerequisites. [ADR 0004](../docs/adr/0004-agents-first-stacks.md) records source references, ownership and acceptance order. kagent/Substrate installation and compatibility with these official gateway releases remain unimplemented acceptance work; selecting source commits does not prove compatible chart or image artifacts exist.

Keep product workloads, agent definitions and behavior in their own repositories. Cluster bootstrap, CRDs and add-ons each have one owner; installation must not compete with another reconciler.

Local Stack/module checks, five runtime mock cases and pinned Helm chart renders pass. The renders verify Temporal server/schema-job TLS and Secret references, immutable images, private services and agentgateway RBAC boundaries. [The Stack guide](../terraform/stacks/agent-runtime/README.md#validation) records the exact evidence and remaining cloud acceptance.
