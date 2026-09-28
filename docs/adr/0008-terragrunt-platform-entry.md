# ADR 0008: Top-level Terragrunt and GCP connection

Status: selected and bootstrap applied on 2026-09-27; GitLab/Gruntwork CI acceptance pending.

Make `terragrunt/` the primary infrastructure entry point. Existing Azure source
moves intact from `terraform/terragrunt/` to `terragrunt/azure/`, preserving explicit
state IDs. New GCP work starts in `terragrunt/gcp/`. Terraform remains the engine;
retained HCP source in `terraform/stacks/` is not converted or deployed by the move.
GitLab remains primary and GitHub a mirror; state remains in the private GitLab
project. Flux separately owns Kubernetes runtime delivery.

The platform core is agentgateway, kagent, agentregistry and Agentdesktop. Google
Workspace/Dex supply identity and Fleet supplies macOS management. The first GCP
increment establishes GitLab OIDC trust for Gruntwork, before runtime provisioning.
See the GCP guide for exact source pins, scope and outstanding cloud acceptance.

No source change grants cloud permissions. The first bootstrap proposes three APIs,
one workload identity pool/provider, two service accounts, two impersonation grants
and one Viewer binding. The apply service account starts without project roles.
Private environment values and plans are excluded from public source and public
outputs. The maintainer selected execution in the existing public GitLab repository,
with state in the existing private project; no additional private live repository is
required. This supersedes ADR 0007's credential-free-only CI restriction for trusted
deploy-branch jobs. Public validation and MR/fork pipelines remain credential-free.

Before enabling cloud jobs, restrict pipeline logs/artifacts to project members,
keep environment files and backend credentials in protected variables, and enforce
immutable project/namespace identity plus protected deploy branch in OIDC trust.
Use separate plan/apply accounts and require explicit approval of a concrete plan
before apply. Never publish real plans in public MR comments. GitHub remains a
validation-only mirror. These are required controls, not a claim that remote CI
settings or Pipelines are already configured.
