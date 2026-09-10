package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestContractCLI(t *testing.T) {
	root := filepath.Join("..", "..", "examples", "contracts")
	cases := []struct {
		name string
		args []string
		want int
	}{
		{"validate", []string{"validate", "--file", filepath.Join(root, "gcp-environment.json")}, 0},
		{"verify", []string{"verify-config", "--file", filepath.Join(root, "gcp-environment.json"), "--snapshot", filepath.Join(root, "synthetic-snapshot.json")}, 0},
		{"missing", []string{"validate"}, 2},
		{"unknown-flag", []string{"validate", "--token=do-not-echo-this"}, 2},
		{"unreadable", []string{"validate", "--file", filepath.Join(t.TempDir(), "missing")}, 2},
		{"missing-snapshot", []string{"verify-config", "--file", filepath.Join(root, "gcp-environment.json")}, 2},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var out, errs bytes.Buffer
			if got := contractCommand(tc.args, &out, &errs); got != tc.want {
				t.Fatalf("exit %d, want %d", got, tc.want)
			}
			if strings.Contains(errs.String(), "do-not-echo-this") {
				t.Fatal("leaked argument")
			}
		})
	}
	p := filepath.Join(t.TempDir(), "document.json")
	if e := os.WriteFile(p, []byte(`{"password":"do-not-echo-this"}`), 0600); e != nil {
		t.Fatal(e)
	}
	var out, errs bytes.Buffer
	if contractCommand([]string{"validate", "--file", p}, &out, &errs) != 1 || strings.Contains(errs.String(), "do-not-echo-this") {
		t.Fatal("invalid input handling")
	}
}
