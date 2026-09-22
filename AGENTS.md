# Agent entry point

Before any task, read and follow [shared development-agent rules](rag/rules/core.md). They are canonical for all models and clients. Do not continue dependent work if this file cannot be loaded.

For Terraform design, implementation, dependency selection or related documentation, also load [Terraform rules](rag/rules/terraform.md) and [Terraform knowledge](rag/knowledge/terraform.md), including when the task starts outside `terraform/`.

See [rag/README.md](rag/README.md) for the shared corpus and portable context command. Native entry points contain routing only; edit canonical rules rather than copying policy here.
