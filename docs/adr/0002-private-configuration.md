# ADR 0002: Public implementation, private configuration and state

Status: proposed; HCP injection mechanism requires the bootstrap acceptance spike.

## Decision

Git contains implementation and synthetic examples. Deployment-specific IDs, addresses, CIDRs, allowlists, origins and provider bindings live in private, versioned configuration. Secret values live in provider secret stores; configuration only references them. Real plans and state are private and access-controlled.

Generated infrastructure values move through component outputs or explicitly published Stack contracts, never through commits back into the repository. Each deployment consumes a pinned configuration snapshot, not a mutable latest object. Pinning and immutable storage permissions must prevent plan/apply input drift.

## HCP validation spike

Verify store/variable-set semantics on the selected Stacks engine before finalizing .tfdeploy.hcl. Stable store values are not assumed to be a universal mutable configuration mechanism. Verify provider authentication, relative module sources, private metadata leakage in logs, and upstream output constraints in a disposable private target. No untested .tfdeploy.hcl file is claimed operational in this foundation.

Bootstrap may use a separate classic Terraform root with a private backend. The operator supplies target bindings privately. No real values are requested in public issues. A versioned GCS/S3/Azure Blob configuration reader is a candidate, not an already implemented backend.

## Security boundaries

Sensitive annotations redact some displays but do not guarantee omission from state. Ephemeral/write-only mechanisms are used only where supported and tested. Protect state backups, provider debug logs and plan JSON as well as HCL. IP redaction is a privacy requirement, not an authentication control.

Reference: https://developer.hashicorp.com/terraform/language/stacks/reference/tfdeploy
Reference: https://developer.hashicorp.com/terraform/language/manage-sensitive-data
