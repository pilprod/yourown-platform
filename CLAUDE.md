# Claude Code entry point

@rag/rules/core.md
@rag/rules/terraform.md

Both small rule files are imported at startup so Terraform design tasks outside `terraform/` receive their scoped instructions too. Follow `rag/knowledge/terraform.md` when working on Terraform. See `rag/README.md` for the shared corpus.

Keep policy in the imported canonical files rather than duplicating it here.
