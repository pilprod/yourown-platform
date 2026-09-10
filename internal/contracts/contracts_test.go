package contracts

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func example(t *testing.T, name string) []byte {
	t.Helper()
	b, e := os.ReadFile(filepath.Join("..", "..", "examples", "contracts", name+".json"))
	if e != nil {
		t.Fatal(e)
	}
	return b
}
func TestExamples(t *testing.T) {
	for _, name := range []string{"gcp-environment", "aws-environment", "azure-environment", "azure-aks-environment", "azure-secret-reference", "workload", "release", "secret-reference"} {
		t.Run(name, func(t *testing.T) {
			if _, e := Validate(example(t, name)); e != nil {
				t.Fatal(e)
			}
		})
	}
}
func TestRejectInvalidDocuments(t *testing.T) {
	env := string(example(t, "gcp-environment"))
	workload := string(example(t, "workload"))
	secret := string(example(t, "secret-reference"))
	cases := map[string]string{
		"wrong-version":     strings.Replace(env, Version, "unrecognized", 1),
		"wrong-kind":        strings.Replace(env, "Environment", "Unknown", 1),
		"cross-provider":    strings.Replace(env, "cloud-run", "ecs", 1),
		"unknown-field":     strings.Replace(env, "{", "{\"secretValue\":\"do-not-echo-this\",", 1),
		"case-alias":        strings.Replace(env, "apiVersion", "ApiVersion", 1),
		"duplicate-key":     strings.Replace(env, "{", "{\"name\":\"other\",", 1),
		"escaped-duplicate": strings.Replace(env, "{", "{\"na\\u006de\":\"other\",", 1),
		"nested-case-alias": strings.Replace(env, "sha256", "SHA256", 1),
		"missing-field":     strings.Replace(env, "\"name\": \"sandbox\",", "", 1),
		"null":              strings.Replace(workload, "\"example-api\"", "null", 1),
		"wrong-type":        strings.Replace(workload, "\"example-api\"", "3", 1),
		"trailing-document": env + "{}",
		"empty":             "",
		"array":             "[]",
		"malformed":         "{",
		"oversized":         strings.Repeat(" ", MaxBytes+1),
		"deep":              strings.Repeat("[", 40) + "1" + strings.Repeat("]", 40),
		"non-utf8":          env + string([]byte{255}),
		"image-tag":         strings.Replace(workload, "sha256:"+strings.Repeat("ab", 32), "latest", 1),
		"origin-in-ref":     strings.Replace(workload, "artifact://example-api", "https://origin.invalid/image", 1),
		"floating-secret":   strings.Replace(secret, "\"1\"", "\"AWSCURRENT\"", 1),
	}
	// Build malformed list explicitly instead of relying on formatting.
	var w map[string]any
	if e := json.Unmarshal([]byte(workload), &w); e != nil {
		t.Fatal(e)
	}
	w["secrets"] = nil
	cases["null-secret-list"] = string(mustMarshal(t, w))
	w["secrets"] = []any{map[string]any{"name": "duplicate", "ref": "secret://sandbox/database", "version": "1"}, map[string]any{"name": "duplicate", "ref": "secret://sandbox/database", "version": "2"}}
	cases["duplicate-secret-name"] = string(mustMarshal(t, w))
	for name, s := range cases {
		t.Run(name, func(t *testing.T) {
			_, e := Validate([]byte(s))
			if e == nil {
				t.Fatal("accepted invalid document")
			}
			var safe Error
			if !errors.As(e, &safe) || strings.Contains(e.Error(), "do-not-echo-this") {
				t.Fatal("unsafe diagnostic")
			}
		})
	}
}
func mustMarshal(t *testing.T, v any) []byte {
	t.Helper()
	b, e := json.Marshal(v)
	if e != nil {
		t.Fatal(e)
	}
	return b
}
func TestSnapshotIntegrity(t *testing.T) {
	env := example(t, "gcp-environment")
	snapshot := example(t, "synthetic-snapshot")
	if e := VerifySnapshot(env, bytes.NewReader(snapshot)); e != nil {
		t.Fatal(e)
	}
	for name, s := range map[string][]byte{"changed": []byte(`{"changed":true}`), "whitespace": append(snapshot, ' '), "empty": {}, "oversized": bytes.Repeat([]byte(" "), MaxBytes+1), "invalid-json": []byte("not-json")} {
		t.Run(name, func(t *testing.T) {
			if VerifySnapshot(env, bytes.NewReader(s)) == nil {
				t.Fatal("accepted altered snapshot")
			}
		})
	}
	if VerifySnapshot(example(t, "workload"), bytes.NewReader(snapshot)) == nil {
		t.Fatal("accepted non-environment")
	}
	if VerifySnapshot(env, brokenReader{}) == nil {
		t.Fatal("accepted read failure")
	}
}

type brokenReader struct{}

func (brokenReader) Read([]byte) (int, error) { return 0, errors.New("private-content-not-for-output") }
