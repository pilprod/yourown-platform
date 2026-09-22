# ADR 0005: Reuse upstream Terraform modules

Status: maintainer-requested direction; agent rules and upstream source composition implemented, cloud acceptance pending.

## Context

The first GCP foundation introduced local implementations of APIs, networking, node identity, Artifact Registry and GKE before evaluating maintained modules. The maintainer requested reuse of `terraform-google-modules` and persistent agent guidance to avoid repeating this unnecessary work.

## Decision

Search maintained upstream modules before writing cloud resource implementations. For GCP, start with [terraform-google-modules](https://github.com/terraform-google-modules); use other Google-published modules when the requested capability is absent there. Inspect suitable submodules as well as root modules.

Use suitable upstream modules directly as HCP Stack components, with explicit source pins, inputs, provider mappings and dependencies. The platform owns composition, lifecycle boundaries and its policy choices. It does not need a local module for every upstream dependency.

A custom module or wrapper requires a recorded unsupported requirement, the candidates examined, source evidence and the smallest local implementation that fills the gap. Input renaming, forwarding outputs, uniform directory shape and easier tests are insufficient reasons. This is a design-evidence requirement, not an additional approval step for already authorized source work.

Review release-specific defaults and preserve intended behavior explicitly. Pin modules independently of provider locks. Do not copy complete upstream repositories into this repository. Review provenance and licensing before reusing implementation.

## Consequences and adoption

This supersedes ADR 0004's suggestion that each platform capability needs its own small resource implementation. It preserves Stack ownership, private configuration, the separate bootstrap boundary and the selected agents-first sequence.

The five initial local cloud implementations have been replaced by direct upstream components. The [GCP Stack guide](../../terraform/stacks/platform-gcp/README.md) records exact pins and the two remaining narrow cloud gaps; the [runtime guide](../../terraform/stacks/agent-runtime/README.md) records chart composition and policy scope. Replacing source for a resource already managed in a live deployment requires a separate ownership and address-migration review; no state operation is authorized here.

Validate the actual resulting Stack and meaningful platform policy behavior. Do not manufacture wrapper modules to retain the old test layout. Static checks and mock tests do not establish cloud acceptance.

[Terraform agent rules](../../rag/rules/terraform.md) and the [context index](../../rag/knowledge/terraform.md) make this decision discoverable before future Terraform work. Native client files are entry points to the same canonical rules; [ADR 0006](0006-shared-agent-context.md) records their shared storage and loading contract. These are agent instructions and review criteria, not a runtime enforcement mechanism.
