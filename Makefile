.PHONY: check fmt-check vet test scan context-check terraform-check stacks-check
check: fmt-check vet test scan context-check

fmt-check:
	@test -z "$$(gofmt -l tools internal)" || (echo "Run gofmt on tools/ and internal/"; exit 1)

vet:
	go vet ./...

test:
	go test -race -count=1 ./...

scan:
	go run ./tools/platformctl scan --root .

# Validate the actual public source bundles without invoking a model.
context-check:
	go run ./tools/platformctl context --root . --topic general >/dev/null
	go run ./tools/platformctl context --root . --topic terraform >/dev/null
	go run ./tools/platformctl context --root . --topic rag >/dev/null

# Separate from Go checks: download pinned packages, without cloud credentials.
TERRAFORM_MODULES := gcp/billing-budget gcp/storage-service-agent runtime/gateway-api runtime/agentgateway runtime/temporal
TERRAFORM_STACKS := platform-gcp agent-runtime

terraform-check:
	terraform fmt -check -recursive terraform/modules
	@set -e; for module in $(TERRAFORM_MODULES); do \
		terraform -chdir=terraform/modules/$$module init -backend=false -input=false; \
		terraform -chdir=terraform/modules/$$module validate; \
		if [ -d terraform/modules/$$module/tests ]; then terraform -chdir=terraform/modules/$$module test; fi; \
	done

stacks-check:
	terraform stacks fmt -check -recursive terraform/stacks
	@set -e; for stack in $(TERRAFORM_STACKS); do \
		terraform -chdir=terraform/stacks/$$stack stacks init; \
		terraform -chdir=terraform/stacks/$$stack stacks validate; \
	done
