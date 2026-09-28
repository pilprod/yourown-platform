"""GitLab runner entry point for the existing GCP bootstrap (no local credentials)."""
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile

TF_VERSION = "1.16.4"
TG_VERSION = "1.1.6"
TF_SHA = "dc94af0eef1147718ad7c8daea792ed199e3e0492eec180d0adafa2a65a879df"
TG_SHA = "d75a80bb264758ba00dabcb17f4b507fcdab4ca90d9e41f96750df036bf69b04"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def guard(env, binding):
    require(env.get("GITLAB_CI") == "true", "GitLab CI is required")
    require(env.get("CI_PROJECT_ID") == str(binding["gitlab_project_id"]), "Wrong GitLab project")
    require(env.get("CI_PROJECT_NAMESPACE_ID") == str(binding["gitlab_namespace_id"]), "Wrong namespace")
    require(env.get("CI_COMMIT_REF_PROTECTED") == "true", "Protected branch required")
    require(env.get("CI_COMMIT_BRANCH") == binding["deploy_branch"], "Wrong deploy branch")
    require(env.get("CI_PIPELINE_SOURCE") in {"web", "api", "push"}, "Unsupported pipeline source")
    require(env.get("CI_DEBUG_TRACE", "false").lower() != "true", "Debug tracing is forbidden")


def request(url, token=None, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def authenticate(binding, mode, oidc):
    provider = ("projects/" + binding["project_number"] + "/locations/global/workloadIdentityPools/"
                + binding["pool_id"] + "/providers/" + binding["provider_id"])
    exchanged = request("https://sts.googleapis.com/v1/token", body={
        "audience": "//iam.googleapis.com/" + provider,
        "grantType": "urn:ietf:params:oauth:grant-type:token-exchange",
        "requestedTokenType": "urn:ietf:params:oauth:token-type:access_token",
        "scope": "https://www.googleapis.com/auth/cloud-platform",
        "subjectTokenType": "urn:ietf:params:oauth:token-type:jwt", "subjectToken": oidc,
    })
    account = binding[mode + "_account_id"] + "@" + binding["project_id"] + ".iam.gserviceaccount.com"
    result = request("https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/" + account + ":generateAccessToken",
                     exchanged["access_token"], {"scope": ["https://www.googleapis.com/auth/cloud-platform"], "lifetime": "3600s"})
    require(bool(result.get("accessToken")), "GCP did not issue an access token")
    return result["accessToken"]


def install(root):
    require(platform.system() == "Linux" and platform.machine() == "x86_64", "Linux AMD64 runner required")
    target = root / ".ci-tools"
    target.mkdir(exist_ok=True)
    packages = [
        ("terraform", "https://releases.hashicorp.com/terraform/" + TF_VERSION + "/terraform_" + TF_VERSION + "_linux_amd64.zip", TF_SHA),
        ("terragrunt", "https://github.com/gruntwork-io/terragrunt/releases/download/v" + TG_VERSION + "/terragrunt_linux_amd64", TG_SHA),
    ]
    for name, url, checksum in packages:
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read()
        require(digest(data) == checksum, "Tool checksum mismatch: " + name)
        if name == "terraform":
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                data = archive.read("terraform")
        path = target / name
        path.write_bytes(data)
        path.chmod(0o700)
    return target


def fingerprint(env, binding):
    return {"commit": env["CI_COMMIT_SHA"], "pipeline": env["CI_PIPELINE_ID"],
            "binding": digest(json.dumps(binding, sort_keys=True).encode()),
            "backend": digest(env["GITLAB_STATE_BASE_URL"].encode()),
            "terraform": TF_VERSION, "terragrunt": TG_VERSION}


def plan_hashes(directory):
    return {str(p.relative_to(directory)): digest(p.read_bytes()) for p in sorted(directory.rglob("*.tfplan"))}


def verify_saved(context, expected, directory):
    require(context["execution"] == expected, "Plan belongs to another commit, pipeline or environment")
    hashes = plan_hashes(directory)
    require(len(hashes) == 8 and context["plans"] == hashes, "Missing or modified saved plans")


def main(mode):
    require(mode in {"plan", "apply"}, "Expected plan or apply")
    os.umask(0o077)
    env = os.environ.copy()
    root = Path(env["CI_PROJECT_DIR"]).resolve()
    binding = json.loads(Path(env["YOUROWN_GCP_ENVIRONMENT_FILE"]).read_text())
    guard(env, binding)
    require(env.get("TF_HTTP_USERNAME") and env.get("TF_HTTP_PASSWORD"), "Private state credentials are missing")
    artifacts = root / ".ci-artifacts"
    plans = artifacts / "plans"
    artifacts.mkdir(exist_ok=True)
    expected = fingerprint(env, binding)
    if mode == "apply":
        verify_saved(json.loads((artifacts / "context.json").read_text()), expected, plans)
        latest = subprocess.check_output(["git", "ls-remote", "origin", "refs/heads/" + binding["deploy_branch"]], text=True).split()[0]
        require(latest == env["CI_COMMIT_SHA"], "Deploy branch advanced; run a new plan")
    # Never fall back to credentials inherited from another authentication mechanism.
    for key in list(env):
        if key.startswith(("GOOGLE_", "TF_VAR_")):
            env.pop(key)
    env["GOOGLE_OAUTH_ACCESS_TOKEN"] = authenticate(binding, mode, env.pop("GCP_OIDC_TOKEN"))
    print("GitLab OIDC and GCP service-account impersonation succeeded for " + mode, flush=True)
    tools = install(root)
    env.update(TG_TF_PATH=str(tools / "terraform"), TF_IN_AUTOMATION="true")
    env["PATH"] = str(tools) + os.pathsep + env["PATH"]
    unit_root = root / "terragrunt/gcp/bootstrap"
    command = [str(tools / "terragrunt"), "run", "--all", "--non-interactive"]
    log = artifacts / (mode + ".log")
    with log.open("w") as output:
        def run(args, allowed=(0,)):
            result = subprocess.run(args, cwd=unit_root, env=env, stdout=output, stderr=subprocess.STDOUT)
            require(result.returncode in allowed, "Terragrunt failed; see restricted " + log.name)
        run(command + ["--", "init", "-reconfigure", "-input=false", "-lockfile=readonly"])
        action = command + ["--no-auto-init", "--out-dir", str(plans)]
        if mode == "plan":
            run(action + ["--json-out-dir", str(artifacts / "json"), "--", "plan", "-input=false", "-detailed-exitcode"], (0, 2))
        else:
            # With --out-dir, Terragrunt applies the saved per-unit plans.
            run(action + ["--", "apply", "-input=false"])
    if mode == "plan":
        hashes = plan_hashes(plans)
        require(len(hashes) == 8, "Expected eight saved bootstrap plans")
        summaries = []
        for path in sorted((artifacts / "json").rglob("*.json")):
            result = json.loads(path.read_text())
            require(not result.get("errored") and result.get("complete"), "Incomplete plan")
            changes = [r["change"]["actions"] for r in result.get("resource_changes", []) if r["change"]["actions"] != ["no-op"]]
            summaries.append({"unit": path.parent.name, "actions": changes})
        require(len(summaries) == 8, "Expected eight plan summaries")
        (artifacts / "context.json").write_text(json.dumps({"execution": expected, "plans": hashes}))
        (artifacts / "summary.json").write_text(json.dumps(summaries, indent=2))
        print(json.dumps(summaries), flush=True)
        print("Review restricted plans before starting the manual apply job.")
    else:
        print("Saved plans applied successfully; state persisted in the private backend.")


if __name__ == "__main__":
    try:
        main(sys.argv[1] if len(sys.argv) == 2 else "")
    except urllib.error.HTTPError as error:
        print("Authentication or tool download failed: HTTP " + str(error.code) + "; response body omitted", file=sys.stderr)
        sys.exit(1)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        print("CI execution failed; sensitive exception details omitted", file=sys.stderr)
        sys.exit(1)
