# RAG design for development agents

Status: design guidance. The current implementation is Markdown in Git plus deterministic file selection; indexed search and database services are not deployed. Primary sources were checked on 2026-09-22.

## Separate responsibilities

| Content | Loading rule | Source of truth |
| --- | --- | --- |
| Core instructions | Always load before executing a task. | Reviewed `rag/rules/core.md`. |
| Domain instructions | Load when task routing selects that domain; relevance scoring cannot omit them. | Reviewed `rag/rules/` topic files. |
| Decisions and factual knowledge | Retrieve according to the task and attach sources. | Original ADRs, project docs and selected upstream revisions. |
| Current implementation | Inspect the actual checkout and diff. | Code, tests and dependency pins. |
| Session observations | Keep ephemeral or submit a reviewed documentation change. | Session state; never automatically authoritative policy. |
| Permission enforcement | Check before the tool or cloud operation. | Runner permissions, IAM, policy checks and CI. |

The model is replaceable; the agent runner owns loading, search, context assembly and tool access. A vector database does not make a model remember or obey instructions. The mandatory rules must remain present even when knowledge search returns no results.

## Retrieval progression

Start with explicit topic routing and file search for this small corpus. Measure failures before adding infrastructure. When the corpus needs indexed retrieval, evaluate a pipeline that filters by access and applicable version, combines lexical and embedding search, deduplicates results and reranks a bounded candidate set. Exact identifiers such as Terraform arguments need lexical matching as well as semantic similarity. [Anthropic's contextual retrieval study](https://www.anthropic.com/engineering/contextual-retrieval) provides evidence for combining lexical/vector retrieval and reranking; its measured gains are not guarantees for this repository.

Split documents at meaningful headings and keep code blocks with their explanations. Preserve the document title, section path and dependency version with every chunk so an isolated paragraph is understandable. Tune chunk size, overlap and result count against local evaluations; there is no universal optimal token count. Retrieve surrounding source when a snippet is ambiguous. Keep any generated contextual summary distinguishable from the original excerpt.

Keep the active context small and useful, with mandatory rules outside the search budget. [Anthropic's context engineering guidance](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) describes selective, task-driven context retrieval. More documents in a prompt are not evidence of better task performance.

## Knowledge records and freshness

For future indexed records, preserve a stable document/chunk ID, original source URI or repository path, content hash, source revision, section, document kind, domain, audience, visibility, review date and status. Add explicit `supersedes` links for replaced decisions and record applicable module/provider versions for technical references. Keep embeddings associated with the embedding model, revision and dimensions. These are index metadata requirements, not fields implemented by the current small manifest.

Keep raw source content separate from derived summaries and embeddings. Rebuild only affected records after a change, remove deleted records and invalidate superseded versions; a stale chunk must not outrank an active decision merely because its wording matches better. Pin a source snapshot for each evaluated run. Re-check a module's actual selected version when upgrading instead of trusting a dated note.

Use citations in answers so an operator can inspect the source. When evidence is missing or contradictory, identify the gap and retrieve more; do not fabricate a confident answer. Never ingest state, private plans, credentials or live inventory into this public corpus. Multi-tenant retrieval must filter unauthorized sources before any context reaches a model or external reranker, including caches.

## Storage recommendation for this project

| Stage | Storage | Trigger |
| --- | --- | --- |
| Current repository knowledge | Markdown and Git; local topic manifest and file search. | Small reviewed corpus and local coding agents. No database is needed. |
| Shared retrieval service | Evaluate PostgreSQL full-text search plus pgvector for embeddings, with access metadata and versioned source records. | Multiple consumers need a shared query API and measured retrieval needs justify operation of a service. |
| Specialized retrieval service | Compare a dedicated search/vector engine with the PostgreSQL baseline. | Measured scale, filtered recall, latency or operational requirements exceed the baseline. |

This progression is a project recommendation, not a universal ranking of databases. [pgvector documents combining vector and PostgreSQL full-text search](https://github.com/pgvector/pgvector#hybrid-search); PostgreSQL full-text search is not automatically BM25. Choose the lexical strategy explicitly and evaluate the combination. PostgreSQL appears in the agent-runtime plan, but no deployed database is established here and the development corpus need not share product data storage.

Store indexes as derived data that can be rebuilt from versioned sources. Keep runtime state and conversations separate from curated knowledge. Share the corpus and retrieval interface across generation models; changing the generation model alone need not rebuild embeddings, while changing the embedding model requires a compatible reindex.

## Evaluation before complexity

Use [the regression scenarios](../evals/README.md) derived from actual mistakes. Measure required-source recall, citation correctness, final behavior, abstention on insufficient evidence and permission-boundary failures separately from latency and token cost. Record the model, template, prompt/adapter version and corpus revision.

Run the same tasks across supported clients and models, including Russian/English paraphrases. Compare against the simple file-search baseline before accepting embeddings, query rewriting or reranking. Loader unit tests prove assembly behavior; they do not prove that an LLM follows a rule or performs a safe operation.
