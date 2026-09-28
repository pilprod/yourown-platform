# ADR 0009: Direct GitLab CI execution

Status: implementation prepared on 2026-09-28; remote acceptance pending.

The maintainer prioritizes leaving local infrastructure execution quickly. Use
GitLab CI to run the existing Terragrunt/Terraform composition directly instead of
waiting for Gruntwork Pipelines onboarding. This supersedes the Gruntwork execution
direction in ADR 0008, while preserving top-level Terragrunt, existing resource
owners, private GitLab state and the already applied GCP OIDC bootstrap.

The public platform repository owns the pipeline. GitHub remains a mirror. Reuse
the existing GCP pool/provider and service accounts; public Gruntwork catalog modules
remain pinned upstream dependencies and do not require the Pipelines service.

Protected-branch plan and manual saved-plan apply use separate GCP identities.
Environment-scoped protected variables isolate state credentials from public
validation. Logs and artifacts remain restricted. Apply must use the reviewed
commit, configuration and artifacts; it cannot silently regenerate a plan.

The first scope is the existing bootstrap. No runtime resources or new project
roles are authorized by this CI migration. The apply account still has no project
roles; permission changes accompany separately reviewed infrastructure plans.
See ci/README.md for installation, credential lifetime and acceptance details.
