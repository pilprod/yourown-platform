# GCP connection to GitLab CI

This first increment prepares trust and two keyless service accounts. It creates
no cluster, VM, database, DNS entry, service-account key or state bucket. The plan
identity gets project Viewer. The apply identity has no project-level roles yet.
Both identities are restricted by the provider condition to the exact GitLab
project ID, namespace ID and protected deploy branch. Merge-request plans are
not enabled by this initial trust policy. The existing public GitLab repository is
the selected execution host. Public validation stays credential-free; protected
deploy-branch jobs may use OIDC after the controls in ADR 0008 are configured.

## Reviewed sources

Reviewed on 2026-09-27. Google Project Factory `project_services` 18.3.0 directly
owns API activation, with both disable-on-destroy options false. Google IAM 8.2.0
was examined for workload identity federation; its IAM submodules do not compose
this complete Gruntwork bootstrap. The remaining units directly consume the
small Terraform modules in Gruntwork's official catalog v1.13.1, commit
`57e280bf81ab9b34b51414c22953e6a1dca788eb`. No local Terraform resource wrapper is added.

The catalog's full GitLab stack was not used unchanged: it defaults to broad apply
roles, a GCS-oriented state model and dependency mocks without command restrictions.
These Terragrunt units retain the upstream resource implementations, use GitLab HTTP
state and explicit ordering, and use no mock outputs. IDs passed between units are
deterministic from the same private environment, so a clean bootstrap can be planned
before any upstream resources exist. API service propagation still requires live checks.

Sources: [Gruntwork GCP authentication](https://docs.gruntwork.io/2.0/docs/pipelines/concepts/cloud-auth/gcp/),
[GitLab setup](https://docs.gruntwork.io/2.0/docs/pipelines/installation/addingexistinggitlabrepo/),
[catalog pin](https://github.com/gruntwork-io/terragrunt-scale-catalog/tree/57e280bf81ab9b34b51414c22953e6a1dca788eb/modules/gcp),
[Google project services](https://github.com/terraform-google-modules/terraform-google-project-factory/tree/v18.3.0/modules/project_services).

## Private inputs and state

Set `TG_TF_PATH=terraform`, `YOUROWN_GCP_ENVIRONMENT_FILE` to an absolute private JSON
file, and `GITLAB_STATE_BASE_URL` to the private state's API base. The JSON requires
`project_id`, `project_number`, `gitlab_project_id`, `gitlab_namespace_id`,
`deploy_branch`, `pool_id`, `provider_id`, `plan_account_id`, `apply_account_id`,
`oidc_audience` and `state_prefix`. Never commit real values.
Backend credentials use `TF_HTTP_USERNAME` and `TF_HTTP_PASSWORD` in the environment.
Each unit's `state.hcl` gives it an explicit stable state suffix. Renaming a checkout
or unit directory does not change this suffix; changing a state suffix needs review.
Do not use local state for an apply or run backend-bootstrap to create storage.

From `bootstrap/`, `terragrunt run --all --non-interactive -- init` initializes the
existing private backend. Run `terragrunt run --all --non-interactive -- plan` and
inspect the full private plan before an approved apply. Commands use Terraform;
Terragrunt does not replace the Terraform engine. Provider locks are per unit.

## Remaining acceptance

Configure direct GitLab CI as described in [the CI guide](../../ci/README.md). Bootstrap is applied; verify
OIDC exchange, both impersonations and denial from another project or
unprotected branch. Future runtime permissions and MR access are separate changes.
The portal's GCP wizard currently says Coming Soon; this is the documented manual
integration path. Installing the GitHub app is not proof of GitLab entitlement.

## Validation evidence (2026-09-27)

With Terraform 1.16.4 and Terragrunt 1.1.6, all eight units passed HCL validation,
backendless provider initialization, Terraform validation and strict input checks
using synthetic bindings. The repository's `make check` passed. Provider lock
files were captured in each unit. These are local checks, not live acceptance.

The selected GCP project and existing private GitLab state project were verified.
The CLI's OAuth token was rejected by HTTP Basic authentication. A fine-grained
personal token scoped only to Terraform State in the private state project resolved
backend authentication. The initial Read/Lock token was replaced, with maintainer
approval, by Create/Lock/Read for apply; the superseded token was revoked. Delete
is not granted. The replacement is stored in macOS Keychain, expires on 2026-10-05,
and is passed only through environment variables.

All eight units produced complete real plans. After explicit maintainer approval,
a fresh plan was compared with the reviewed resource values and confirmed identical:
ten additions, no updates or deletions. Saved plans were applied successfully to
all eight units. A subsequent plan returned exit zero with no changes in every unit.
Both service accounts have zero user-managed keys. Full plans, state-derived outputs
and logs remain in private storage. This confirms bootstrap and remote state
persistence, but does not yet prove GitLab OIDC exchange or Gruntwork execution.

The maintainer selected direct protected GitLab CI execution to leave local runs
quickly (ADR 0009). The prepared pipeline uses GitLab-to-Google OIDC, private state
and manual saved-plan apply. It does not call the Gruntwork service. CI lint, local
checks and live pipeline acceptance are separate; see ci/README.md for the contract.

References: [fine-grained state permissions](https://docs.gitlab.com/auth/tokens/fine_grained_access_tokens_rest/#terraform-state),
[GitLab GCP OIDC](https://docs.gitlab.com/ci/cloud_services/google_cloud/).
