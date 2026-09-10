# Reference-only contracts: v1alpha1

Implemented: Environment, Workload, Release and SecretReference schemas and a matching Go validator. All fields are required; use an empty secrets array when none are needed. Unknown fields, null and case aliases are rejected. The Go validator additionally rejects duplicate JSON keys, duplicate secret names, documents over one MiB and nesting over thirty-two levels. JSON Schema alone cannot detect duplicate JSON keys.

This is an alpha vocabulary, not a deployment API. It does not guarantee compatibility with an implemented runtime. Provider-specific sizing/network/ingress contracts will be added with each runtime, rather than pretending ECS, Cloud Run and Azure Container Apps have identical semantics.

## Local commands

```sh
go run ./tools/platformctl validate --file examples/contracts/gcp-environment.json
go run ./tools/platformctl validate --file examples/contracts/workload.json
go run ./tools/platformctl verify-config \
  --file examples/contracts/gcp-environment.json \
  --snapshot examples/contracts/synthetic-snapshot.json
```

`config://`, `environment://`, `artifact://`, `workload://` and `secret://` are logical references, not URLs that this CLI fetches. Their real provider bindings belong in private configuration. No secret value, deployed origin, account identifier or IP belongs in these public documents. An image repository reference resolves privately; its digest is immutable. Secret versions are explicit; floating labels are rejected.

`verify-config` validates an Environment and compares the SHA-256 of the exact snapshot bytes, including whitespace, with its declared checksum. It accepts only bounded, valid UTF-8 JSON snapshots. It neither prints nor copies snapshot contents. It does not authenticate the manifest, validate a private provider-specific schema, lock cloud objects, or connect the snapshot to an HCP run. A trusted, approved manifest plus a pinned object version and read-only private runner are still required. Changing both the manifest and snapshot defeats a checksum-only control.

## Remaining integration work

Implement provider-specific snapshot readers and HCP input wiring, verify their store/ephemeral semantics, and prove plan/apply input stability privately. This increment does not implement a generic YAML-to-Terraform language or create operational `.tfdeploy.hcl` files. Issues #4 and #5 remain open until their private acceptance criteria pass.

## Provider/runtime vocabulary

| Provider | Accepted runtime values | Runtime implementation |
|---|---|---|
| `gcp` | `cloud-run`, `gke` | Planned |
| `aws` | `ecs`, `eks` | Planned |
| `azure` | `container-apps`, `aks` | Planned |

Cross-provider pairs and case aliases are rejected. Azure does not add tenant/subscription/client IDs to public Environment fields. An Azure Blob configuration binding, ACR repository URI or Key Vault secret identifier is resolved privately from the existing logical reference. The Azure secret example uses a synthetic explicit version; it is not a real vault reference. Actual provider-specific version validation belongs in the private resolver and remains unimplemented.

```sh
go run ./tools/platformctl validate --file examples/contracts/azure-environment.json
go run ./tools/platformctl validate --file examples/contracts/azure-aks-environment.json
go run ./tools/platformctl verify-config \
  --file examples/contracts/azure-environment.json \
  --snapshot examples/contracts/synthetic-snapshot.json
```
