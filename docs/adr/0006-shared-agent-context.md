# ADR 0006: Shared rules and knowledge for development agents

Status: maintainer-requested direction; corpus and local bundle implemented, live client/model acceptance pending.

## Decision

Keep a dedicated `rag/` directory in this repository as the canonical source for development-agent instructions and knowledge navigation. Every model and client uses the same reviewed sources. Keep decisions and implementation documentation at their original paths and reference them rather than creating divergent copies.

Mandatory core and topic rules load deterministically. Task knowledge is separate evidence and may be selected by search. Search results cannot replace instructions or grant tool permissions. Native `AGENTS.md`, `CLAUDE.md` and editor files remain thin entry points to the canonical policy.

A read-only Go command assembles a model-neutral JSON bundle from an explicit manifest, keeping rules and knowledge separate with source paths and content hashes. It does not invoke models or retrieve from a database. Each API runner must map the bundle to its provider's instruction and message format, enforce context budgets and tool access, and pass behavior acceptance for its selected model/template.

Start with Git, Markdown, topic selection and file search. A shared retrieval API and indexed search require demonstrated needs and evaluation against this baseline. PostgreSQL with full-text and vector search is a candidate, not a selected or deployed cloud resource.

## Consequences

Terraform policy and its knowledge index live in `rag/`; client entry points and documentation link directly to those canonical sources. ADR 0005's upstream-module preference remains unchanged. Current infrastructure progress is tracked in [the implementation plan](../implementation.md).

The developer corpus is not a product-agent prompt and does not give kagent agents administrator access. Private tenant data, session logs, credentials and generated indexes remain separate. Rule edits require normal source review; agents do not automatically rewrite policy from their own responses.

See [the context guide](../../rag/README.md), [adapter contract](../../rag/adapters/README.md) and [acceptance scenarios](../../rag/evals/README.md). Local assembly tests prove file selection and validation, not rule compliance by a model.
