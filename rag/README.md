# Shared agent rules and knowledge

This directory is the canonical context source for agents developing YourOwn Platform, independent of model vendor. Keep it in this repository so the rules and code are reviewed and versioned together.

## Layout

```text
rag/
  rules/          mandatory core and topic instructions
  knowledge/      task references and retrieval guidance
  manifest.json   explicit source selection for portable bundles
  adapters/       client integration contract
  evals/          behavior scenarios for client/model acceptance
```

Architecture decisions and implementation status remain in `docs/`; knowledge points to these original sources. Avoid copied documents that can diverge. Do not store generated indexes, embeddings, private configuration or conversation dumps here. Local disposable artifacts belong under the ignored `.local/` directory.

## Load context

- Every task loads [core rules](rules/core.md). Terraform tasks also load [Terraform rules](rules/terraform.md), regardless of the starting directory.
- `AGENTS.md`, `CLAUDE.md` and editor rules are thin client entry points to the same canonical files.
- API agents use the local command below, then map its separate `rules` and `knowledge` fields through their provider adapter.

From the repository root, with the repository's Go toolchain:

```sh
go run ./tools/platformctl context --root . --topic terraform
```

Available topics are `general`, `terraform` and `rag`. The manifest selects complete files; this first implementation performs no semantic search. Output is JSON containing the topic and ordered rule/knowledge documents, each with its repository path, SHA-256 and content. It reads the current working tree, including uncommitted edits. Record the bundle hashes for reproducibility; a content hash is not proof that a source is trustworthy.

The command fails on missing required context, unknown topics or invalid input rather than producing a partial bundle. Input limits are 64 KiB per file and 256 KiB in total; the client must separately enforce the selected model's token budget. It does not send content to a model, configure a vLLM server or enforce tool permissions. See the [adapter contract](adapters/README.md) for the remaining client work.

## What to read next

- [RAG design and database choices](knowledge/retrieval.md).
- [Terraform knowledge](knowledge/terraform.md).
- [Shared-context decision](../docs/adr/0006-shared-agent-context.md).
- [Model and client evaluation scenarios](evals/README.md).

## Acceptance boundary

Source files, native entry points and a local portable bundle are implemented. `make check` validates the repository and assembles each configured topic; the Go tests check bundling failures and rule/evidence separation. These checks do not demonstrate that a model follows the rules. Live Claude Code/API, vLLM adapters, model behavior evaluations, embeddings and a shared retrieval service remain separate acceptance work.
