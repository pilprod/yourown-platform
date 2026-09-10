# Terraform capabilities

Status: planned. No deployable .tf or Stack configuration is included yet.

- bootstrap/: classic root configurations for initial HCP/GCP/AWS trust and private state.
- modules/gcp/: provider-specific reusable project, IAM, network, registry, runtime, data and delivery blocks.
- modules/aws/: provider-specific baseline, IAM, network, ECR, ECS/EKS, RDS, storage and delivery blocks.
- modules/cloudflare/: edge, DNS/security, Access, optional Tunnel/Workers and administrative MCP integration.
- stacks/: HCP composition separated by provider, lifecycle and owner.

Add only the capability implemented by an active task. Modules contain typed inputs/outputs and no embedded provider credentials, account bindings, backends or product defaults. Keep deployment-specific configuration private. Pin engine and provider versions when their acceptance spike is complete; commit reviewed provider locks.
