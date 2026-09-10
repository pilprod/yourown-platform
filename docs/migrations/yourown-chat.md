# Migration boundary: yourown-chat

The current repository is reference material, not a deployment target for this foundation. Do not copy live .tfdeploy.hcl values or Git history. Review reusable modules and charts for provenance, licensing, product assumptions and disclosure before transferring code.

For each live resource, record its current owner/state, proposed owner/state, dependencies, backup, rollback and migration method in private operational records. Keep current ownership until the new configuration is validated. Transfer one owner at a time and prevent concurrent applies.

Never import the same resource into a new active Stack while the old Stack still manages it. Do not use a mass rename or recreate as a default migration plan. No live ownership transfer has been performed by the initial foundation work.

Source boundary reference: https://github.com/pilprod/yourown-chat/blob/main/docs/AGENT_PLATFORM.md
