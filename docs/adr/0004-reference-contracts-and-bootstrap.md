# ADR 0004: Reference contracts and trust-first bootstrap

Status: proposed; local implementation available, cloud acceptance pending.

The initial contract vocabulary is deliberately reference-only. It supports logical environments, workloads, immutable releases and versioned secret references without publishing cloud bindings. Go performs strict parsing plus semantic validation; JSON Schemas document the structural contract. The CLI does not fetch secrets, render Terraform or call a cloud API.

An Environment records a logical configuration reference and SHA-256. Verification checks exact bytes, not a claim of immutability or authenticity. Private ingestion must pin an actual GCS generation/S3 version, authenticate the approved manifest and bind the same snapshot to the HCP run. The checksum tool alone does not satisfy the entire private-configuration acceptance task.

Bootstrap roots are classic Terraform with explicitly private remote backends, independent of the Stacks they will authorize. Distinct plan/apply identities trust exact HCP subjects. AWS's OIDC provider is account-owned and reused; GCP also binds the immutable Stack ID. Initial identities have no infrastructure or secret permissions; those are added deliberately for each capability.

Phase-aware provider selection, actual HCP input/store behavior, private object retrieval, engine/provider lockfiles and live token exchange remain acceptance work. Do not disguise these missing integrations with a generated deployment file or public test credentials. GitHub CI is temporarily deferred by explicit maintainer direction; retained files are not proof of execution.
