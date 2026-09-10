# ADR 0001: Shared core, explicit provider implementations

Status: proposed for maintainer acceptance with the foundation PR.

## Decision

Maintain one public repository for infrastructure implementation and administrative tooling across YourOwn products. Keep product code and runtime user data outside it. Implement first-party executable tools in Go and cloud resources through Terraform modules composed by HCP Stacks.

Separate foundation, network, runtime, data, delivery and edge ownership. Create instances per target/environment as needed; do not make the entire platform one state. Cloud Run/ECS and GKE/EKS expose explicit provider semantics rather than a misleading generic container abstraction.

GCP, AWS and Cloudflare are all in scope. Implement GCP serverless as the first vertical deployment slice, alongside AWS baseline identity and configuration. Kubernetes and expensive shared services remain optional. Document capability maturity.

Platform administrative MCP is separate from product MCP. Initial tooling is read-only, with target allowlists and server-side authorization. Proposals and plan requests require review; production apply remains an independently approved action.

## Consequences

Reusable code and policy do not imply shared tenant credentials, networks or data. A new product must be attachable without changes to reusable modules. Existing Chat infrastructure remains under its current owners until a reviewed migration.
