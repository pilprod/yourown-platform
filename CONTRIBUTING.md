# Contributing

Start with an issue and a small acceptance slice. Read AGENTS.md, SECURITY.md and the ADRs. All example configurations must be synthetic and use logical references rather than deployed inventory.

Run `make check` with staged files. Run Gitleaks locally before a public push when installed. The CI workflow includes the same Go checks and a separate Gitleaks job. No real cloud credential belongs in either job.

Use additive contract changes and independent provider implementations. Pin dependencies and document upgrade evidence. For a resource move, include the old owner, new owner, rollback approach and private plan review; do not paste the plan into the PR.

The maintainer must decide and add an explicit license before accepting contributions intended for an open-source release.
