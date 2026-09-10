# delivery

Status: planned unless explicitly stated otherwise.

Planned: provider-specific build/deploy templates. Terraform owns cloud pipeline infrastructure; products own source, tests, image build context and schema migrations. Pin image digests and define a single workload revision owner.

Azure delivery is a separate planned implementation using ACR and an explicitly selected cloud-native pipeline (such as Azure Pipelines). Pipeline/source integration, federated service connections, permissions and pricing must be verified before deployment. HCP identities and pipeline identities must not share credentials or trust. No GitHub CI activation is required.
