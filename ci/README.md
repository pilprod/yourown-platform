# Direct GitLab execution

The active migration target is GitLab CI running Terragrunt and Terraform directly.
Gruntwork Pipelines is not required. The first execution scope is the existing eight
GCP bootstrap units; no runtime deployment or additional GCP permissions are included.

Public MR validation receives no environment-scoped state credentials and requests
no cloud token. Cloud jobs require an explicitly enabled pipeline, the protected
default branch, and a push, web or API pipeline. GCP independently checks the exact
GitLab project/namespace and protected branch. The runner also rejects debug tracing.

## Project setup

Keep the repository public, set CI/CD visibility to project members only, disable
public pipelines, and disable fork pipelines in the parent project before enabling
cloud jobs. Keep the default branch protected. Do not use the GitHub mirror for apply.

Configure these protected project CI variables with expansion disabled:

| Variable | Type | Environment scope | Purpose |
| --- | --- | --- | --- |
| `YOUROWN_GCP_CI_ENABLED` | Variable | `*` | Set `true` after setup; controls creation of cloud jobs |
| `GCP_OIDC_AUDIENCE` | Variable | `*` | Must match the existing GCP provider allowed audience |
| `YOUROWN_GCP_ENVIRONMENT_FILE` | File | `gcp/bootstrap` | Existing private environment JSON; never publish its contents |
| `GITLAB_STATE_BASE_URL` | Variable | `gcp/bootstrap` | Existing private GitLab state project API base |
| `TF_HTTP_USERNAME` | Variable | `gcp/bootstrap` | Backend token owner |
| `TF_HTTP_PASSWORD` | Masked and hidden variable | `gcp/bootstrap` | State token restricted to Create/Lock/Read in the private state project |

State token expiry is an operational dependency: renew it in GitLab before expiry.
No Google service-account key or local gcloud session is required by CI. GitLab
issues an ID token; the runner exchanges it with Google STS and impersonates the
selected plan/apply account for at most one hour. Jobs have a 30-minute timeout.
Credentials are not saved in artifacts. The token's state-write scope does not grant
GCP write permissions; those remain controlled by each service account's IAM roles.

## Review and apply

`gcp-plan` creates per-unit binary/JSON plans and private logs. Artifacts are restricted
to Maintainers and expire after one day. Review them before starting `gcp-apply`,
which is always manual and applies those saved plans. Both jobs share a resource
group; backend locking remains enabled. Apply verifies commit, pipeline, input and
backend fingerprints, each binary plan checksum, and the latest deploy-branch SHA.
If plans expire or the branch advances, run a new pipeline. No automatic replan is
performed by apply. Failed jobs retain restricted diagnostic logs.

Terraform and Terragrunt binaries are pinned by release and verified SHA-256;
runner images are pinned by digest. The runner downloads pinned modules during init
with read-only provider lock files. Full plans and logs never go to public MR comments.

`ci/gcp.py` is narrow CI glue for credential exchange and saved-plan execution;
Terraform resource implementations remain in the existing pinned upstream modules.
The current apply service account has no project roles: enabling the job does not
authorize future infrastructure changes or make them deployable without IAM review.

## Checks

Run `python3 -m unittest discover -s ci -p 'test_*.py'` for negative trust and artifact
integrity checks, `make check` for repository checks, and GitLab CI lint for YAML.
Live OIDC, remote plan and saved-plan apply must be recorded separately after a
successful pipeline; local tests do not establish remote acceptance.
