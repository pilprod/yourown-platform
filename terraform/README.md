# Terraform capabilities

Status: scoped identity modules and classic GCP/AWS bootstrap roots are implemented source; Terraform CLI/provider validation and cloud acceptance remain pending. Operational HCP Stack configurations and runtime modules are not implemented yet.

- bootstrap/: classic root configurations for initial HCP/GCP/AWS trust and private state.
- modules/gcp/: provider-specific reusable project, IAM, network, registry, runtime, data and delivery blocks.
- modules/aws/: provider-specific baseline, IAM, network, ECR, ECS/EKS, RDS, storage and delivery blocks.
- modules/cloudflare/: edge, DNS/security, Access, optional Tunnel/Workers and administrative MCP integration.
- stacks/: HCP composition separated by provider, lifecycle and owner.

Add only the capability implemented by an active task. Modules contain typed inputs/outputs and no embedded provider credentials, account bindings, backends or product defaults. Keep deployment-specific configuration private. Pin engine and provider versions when their acceptance spike is complete; commit reviewed provider locks.

Implemented source now includes `modules/hcp/stack-subjects`, `modules/gcp/stack-identity`, `modules/aws/stack-identity` and classic `bootstrap/gcp` / `bootstrap/aws` roots. The authored Terraform tests and provider-schema validation remain to be run with an installed CLI and provider registry access. No operational HCP Stack or actual cloud resource is claimed by these files. See `bootstrap/README.md`.
