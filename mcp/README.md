# mcp

Status: planned unless explicitly stated otherwise.

Planned: administrative catalog, policy/instructions and Go adapters for HCP/GCP/AWS/Azure. Begin with target-scoped read-only status/inventory. Do not expose raw state, secrets, arbitrary execution or automatic apply. Product MCP is separate.

Azure adapter acceptance must bind both tenant and subscription from private target references. Do not expose arbitrary Azure CLI/ARM execution or inherit platform access from product users. Azure adapters are not implemented by the bootstrap module.
