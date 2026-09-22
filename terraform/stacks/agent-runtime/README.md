# Agent runtime Stack

Status: reusable source composition. Private binding, cluster connectivity and cloud acceptance must be verified before deployment. This Stack owns runtime namespaces and selected Helm releases on an existing GKE cluster; [platform-gcp](../platform-gcp/README.md) owns cloud resources. kagent and Substrate installation remain a separate release-selection task.

## Dependencies and justified local scope

| Capability | Pinned upstream source | Local behavior |
| --- | --- | --- |
| Cluster authentication | [GKE auth 45.0.0](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/tree/v45.0.0/modules/auth) | Direct Stack component; private endpoint selected. |
| Gateway API | [Official standard release v1.6.0](https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.6.0) | HTTP retrieval with reviewed SHA-256; Kubernetes owns the unchanged manifests, including admission policies. Destruction is blocked. |
| agentgateway | [Official charts v1.5.0](https://github.com/agentgateway/agentgateway/tree/v1.5.0/controller/install/helm) | Namespace/service account, chart ordering and scoped RBAC. Charts and controller/proxy images use immutable digests. |
| Temporal | [Official chart 1.2.0](https://github.com/temporalio/helm-charts/tree/temporal-1.2.0/charts/temporal) | Namespace, quota, container limits, network access and existing database/CA Secret references. Server/admin-tools 1.31.0 images use registry-verified immutable digests. |

Dependencies and source interfaces were inspected on 2026-09-22. GKE auth and Gateway API are Apache-2.0; agentgateway is Apache-2.0 and Temporal Helm charts are MIT. Upstream implementation is referenced, not copied into local cloud wrappers. The runtime modules compose application-specific Helm values and Kubernetes ownership/policy that the GCP cloud modules do not implement. No suitable official Gateway API Helm chart was confirmed; [the upstream request](https://github.com/kubernetes-sigs/gateway-api/issues/4809) remains open. A release asset is fetched through the HTTP provider with SHA-256 verification, not a shell provisioner. Its schema examples are not imported into the repository corpus.

The source-only migration from `yourown-chat` preserves common runtime capability and release pins. Chat database identities, namespace defaults, bootstrap passwords, SQL Studio users, historical state operations and deployment values stay in the source project. No source change transfers ownership of existing resources.

## Private inputs and ownership

Supply `target` (project, region, cluster name/location), `federation` (audience and scoped service account) and an ephemeral sensitive `identity_token`. Google authentication is configured explicitly; Kubernetes and Helm receive the auth component's host, CA and short-lived token. There is no ambient kubeconfig fallback. The approved runner needs private cluster connectivity and enough permissions for the selected runtime; provider configuration is not authorization to deploy.

`runtime.agentgateway` and `runtime.temporal` are required maps; empty maps disable their respective capabilities. Each entry supplies its namespace, release/service-account names and capacity. There can be at most one agentgateway entry and namespaces must be distinct. Removing a deployed entry is a destructive operation, not a safe disable switch.

agentgateway discovery accepts explicit namespace names. Product delivery owns its namespaces, Gateways, routes, policies and RoleBindings to the exported deployer ClusterRole. The platform creates no application namespace write binding. The upstream controller ClusterRole still includes cluster discovery (including Secrets), status updates, GatewayClass reconciliation and TokenReview creation; it must not be described as read-only. Runtime and product administrators must review that privilege scope before installation. CRDs and controller are separate releases; prerequisite RBAC exists before Helm waits for controller readiness. Existing CRD owners must be reviewed before any future deployment; field conflicts are not forcibly overridden.

Temporal takes an explicit private PostgreSQL host/port, egress CIDRs, separate persistence/visibility database names and users, an existing credential Secret, and an existing CA Secret plus verified TLS server name. The Secrets must be populated in the runtime namespace by a separately owned, approved secret integration; this Stack neither reads nor creates their values. Database creation belongs to cloud infrastructure. `manage_schema` explicitly selects chart schema mutation; the selected users need the corresponding schema permissions. With this flag disabled, chart 1.2.0 removes the schema init containers but retains its no-op completion Job. CA mounts apply to both server and schema jobs. Treat `history_shards` as immutable after initial deployment.

Network policy allows intra-namespace traffic, configured worker/client namespaces on the frontend gRPC port, DNS to the supplied cluster DNS address, and database traffic only to the supplied egress CIDRs/port. Worker namespaces retain responsibility for their own egress policy. The database host, TLS identity and CIDRs must describe the same private endpoint. This provides namespace-level network restriction, not application authentication or mTLS between Temporal clients and the service. Web/admin-tools deployments and version checks are disabled; no public service is created.

## Validation

Use the pinned Terraform toolchain:

```sh
terraform -chdir=terraform/stacks/agent-runtime stacks init
terraform -chdir=terraform/stacks/agent-runtime stacks validate
```

Validate local modules separately with `terraform init -backend=false`, `terraform validate` and their `terraform test` checks. Mock tests check selected policy/negative cases without cloud credentials. Stack validation does not read a cluster, fetch a real deployment input or demonstrate chart readiness. Cloud acceptance still requires reviewed resource/IAM ownership, secret references and private connectivity, followed by an explicitly approved disposable target. No public deployment binding is supplied.

Local evidence on 2026-09-22: actual Stack validation, all three local module validations and five mock cases passed. A checksum-verified disposable Helm 3.20.2 binary (matching the Helm provider engine) rendered the exact chart pins with source-derived synthetic values and Kubernetes 1.35 capabilities. Rendered manifests confirm CA mounts and verified database TLS on Temporal servers and schema init containers, existing credential references, immutable workload images, private services, and the schema-enabled/disabled behavior described above. agentgateway renders its expected roles without application RoleBindings. Verification artifacts remain ignored under `.local/runtime-render/`; this is local rendering evidence, not cluster acceptance.
