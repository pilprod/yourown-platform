# ADR 0003: Unprivileged public checks, private infrastructure changes

Status: proposed for maintainer acceptance with the foundation PR.

## Decision

GitHub public CI performs local validation and security tests with contents:read and no cloud credentials. HCP runs real plans/applies privately after trusted changes and explicit approval. Never expose a production plan in a public PR comment or artifact.

Use short-lived OIDC for HCP/GCP/AWS/Azure where supported, distinct identities for plan/apply and narrow target trust conditions. A public repository path alone is not sufficient trust. Cloudflare credentials remain separately scoped and private.

Terraform owns infrastructure and the workload fields explicitly assigned to it. Product build pipelines produce immutable image digests; the first Cloud Run delivery path submits the digest to the workload Stack. Do not also let Cloud Deploy overwrite the same revision configuration. Kubernetes delivery has one declared reconciler; application schema migrations belong to the product.

No force push, automatic state migration, destroy or production apply is part of the foundation PR. Move ownership only with private no-op/expected-change evidence, backup and rollback.

Repository rule enforcement, required reviewers and secret/push protection require maintainer administration; a CODEOWNERS file alone does not enable them.

Reference: https://docs.github.com/en/actions/reference/security/secure-use
Reference: https://developer.hashicorp.com/terraform/language/stacks/deploy/authenticate
