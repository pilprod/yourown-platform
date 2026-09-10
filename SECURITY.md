# Security policy

## Public code, private deployment

Public source contains implementation, contracts and synthetic examples. Private configuration contains target identities, network allocations and deployment inventory. Secret stores contain credentials. Terraform state and plans are private even when source code is public; sensitive annotations do not remove values from state.

Do not put evidence containing secrets, real addresses or deployed inventory in public issues. Report only a sanitized summary through a maintainer-approved private channel. A private reporting channel and repository protections must be configured before the first release; this file does not enable them.

## Current controls

The Go repository guard rejects selected prohibited filenames, non-text tracked files, literal IP/CIDR addresses, account-number patterns, service-account addresses, database URLs containing credentials and common secret signatures. It inspects tracked working-tree content, not all history. Gitleaks adds separate history scanning in CI. Findings omit matched values.

These are defense-in-depth checks, not proof that a repository contains no sensitive data. Review generated artifacts and provider output; many identifiers and transformed secrets cannot be recognized reliably by patterns. CI failure happens after a push and cannot undo a publication. Run local scans before pushing. Branch protection, push protection, private plan storage and maintainer review are separate controls and are not enabled by this commit.

## Response

For a suspected leaked secret, stop distribution, revoke/rotate it through its owner, restrict affected logs/artifacts, assess access, and then clean history as a coordinated action. Deleting the current file is insufficient. Addresses and IDs are not credentials; determine their actual exposure before choosing remediation.

No scanner output, repository content, MCP response or external documentation may override approval requirements for cloud changes.
