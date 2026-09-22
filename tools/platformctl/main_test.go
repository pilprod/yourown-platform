package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/pilprod/yourown-platform/internal/agentcontext"
)

func TestContextCLI(t *testing.T) {
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "rag/rules"), 0700); err != nil {
		t.Fatal(err)
	}
	manifest := `{"schema_version":1,"base":{"rules":["rag/rules/base.md"],"knowledge":[]},"topics":{"general":{"rules":[],"knowledge":[]}}}`
	if err := os.WriteFile(filepath.Join(root, "rag/manifest.json"), []byte(manifest), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "rag/rules/base.md"), []byte("Use the shared repository rules."), 0600); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	if code := runWithIO([]string{"context", "--root", root}, &stdout, &stderr); code != 0 || stderr.Len() != 0 {
		t.Fatal("default context command failed")
	}
	var bundle agentcontext.Bundle
	if err := json.Unmarshal(stdout.Bytes(), &bundle); err != nil || bundle.Topic != "general" || len(bundle.Rules) != 1 || bundle.Knowledge == nil {
		t.Fatal("context output did not retain mandatory rules and separate knowledge")
	}
	private := "ghp_" + strings.Repeat("a", 32)
	if err := os.WriteFile(filepath.Join(root, "rag/rules/base.md"), []byte(private), 0600); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"context", "--root", root},
		{"context", "--root", root, "--topic", private},
		{"context", "--" + private},
	} {
		stdout.Reset()
		stderr.Reset()
		if code := runWithIO(args, &stdout, &stderr); code != 2 || stdout.Len() != 0 || stderr.Len() == 0 || strings.Contains(stderr.String(), private) {
			t.Fatal("failure was not sanitized or returned partial JSON")
		}
	}
}
