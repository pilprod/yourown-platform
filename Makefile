.PHONY: check fmt-check vet test scan
check: fmt-check vet test scan

fmt-check:
	@test -z "$$(gofmt -l tools internal)" || (echo "Run gofmt on tools/ and internal/"; exit 1)

vet:
	go vet ./...

test:
	go test -race -count=1 ./...

scan:
	go run ./tools/platformctl scan --root .
