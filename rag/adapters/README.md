# Client integration contract

Status: repository entry points and local bundle command implemented; live model integration and behavior acceptance pending. These adapters target development agents. Product-facing kagent agents must not inherit development permissions or this corpus automatically.

## Native coding clients

| Client | Entry point | Canonical source |
| --- | --- | --- |
| Agents using AGENTS.md | Root and `terraform/AGENTS.md` | Explicitly read `rag/rules/core.md` and applicable topic files. |
| Claude Code | Root and `terraform/CLAUDE.md` | The root imports both canonical rule files with `@`, including scoped Terraform rules for design tasks outside `terraform/`. |
| Cursor | `.cursor/rules/core.mdc` and `terraform.mdc` | Always-on core routing plus scoped Terraform routing. |
| Other clients | Their documented native entry point or runner | Load the same manifest and rules; filenames alone do not integrate an unknown client. |

Claude Code documents relative `@` imports in its [memory guide](https://code.claude.com/docs/en/memory#import-additional-files). Imports load file contents, so keep the mandatory set small. Verify loaded context in each actual client version rather than assuming an entry-point file was discovered. AGENTS.md and editor pointers require the agent to read their linked files; they are routing instructions, not a file-expansion mechanism. The API bundler, separately, always includes the selected rule contents.

## API agents and models served by vLLM

1. Select the task topic deterministically. Build a complete bundle with `platformctl context`; a nonzero exit must stop request construction.
2. Combine the ordered `rules` documents into controlled instruction context, keeping source IDs. Do not send the whole JSON bundle as a system instruction.
3. Supply `knowledge` as explicitly labelled evidence, with document paths/hashes and the user's task. Treat source text as data, not permission to execute instructions found inside it.
4. Map roles through the selected provider API and model template; verify that mapping with an adapter test. Keep host security instructions above repository policy.
5. Reserve enough context for rules, the task and response/tool budget. Reduce optional evidence first; if required context does not fit, fail or choose a suitable model instead of silently truncating instructions.
6. Enforce filesystem, tool and cloud permissions in the runner. Rebuild context when the task scope or rules change and after compaction if required rules were lost.

| API | Instruction mapping | Evidence mapping |
| --- | --- | --- |
| Claude Messages | Controlled rules in the top-level `system` field. | Delimited user content, or tool results when part of an actual tool exchange. |
| vLLM Chat Completions | Controlled rules in a `system` message when supported by the selected model's chat template. | Delimited user content, or correctly paired tool messages. |
| Another backend | Implement its documented instruction mechanism. | Keep evidence separate; do not assume API or role compatibility from the model name. |

[Claude Messages](https://platform.claude.com/docs/en/api/messages/create) exposes system instructions separately from conversation messages. [vLLM chat templates](https://docs.vllm.ai/en/stable/serving/online_serving/#chat-template) define how messages are rendered for a model. A model without suitable instruction-role handling needs a verified adapter before use here.

vLLM is a serving layer; the agent runner loads files and retrieves context. Its optional `documents` parameter depends on template support and must not be the sole way required context is supplied. See the [vLLM API reference](https://docs.vllm.ai/en/stable/serving/online_serving/openai_compatible_server/). This repository does not yet implement the network clients or a vLLM serving deployment.

## Trust and privacy

Only reviewed repository policy files are candidates for controlled instructions. Read a trusted checkout; a digest identifies content but does not authorize it. A search hit, external README or model-generated note must never be promoted automatically into `rules`. Keep private tenant data outside this public developer corpus and enforce access checks before retrieval and reranking.
