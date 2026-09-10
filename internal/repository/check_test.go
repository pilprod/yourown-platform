package repository

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestInspect(t *testing.T) {
	ip := fmt.Sprintf("%d.%d.%d.%d", 192, 0, 2, 4)
	ipv6 := strings.Join([]string{"2001", "db8", "", "1"}, ":")
	cases := []struct {
		name, path, body string
		want             bool
	}{
		{"plain text", "README.md", "Use private configuration references.", false},
		{"module version", "go.mod", "go 1.23.0", false},
		{"reference", "sample.json", "secretref:database-runtime", false},
		{"IPv4", "config.hcl", "origin = " + ip, true},
		{"IPv4 CIDR", "network.hcl", ip + "/24", true},
		{"IPv6", "config.hcl", "[" + ipv6 + "]", true},
		{"IPv6 CIDR", "config.hcl", ipv6 + "/64", true},
		{"IPv6 loopback", "config.hcl", ":" + ":1", true},
		{"URL address", "notes.md", "https://" + ip + "/mcp", true},
		{"state", "terraform.tfstate", "{}", true},
		{"plan", "production.tfplan", "binary", true},
		{"environment", ".env.local", "empty", true},
		{"tfvars", "prod.tfvars", "empty", true},
		{"private key", "notes.md", "-----BEGIN " + "PRIVATE KEY-----", true},
		{"account", "config.hcl", strings.Repeat("1", 12), true},
		{"service account", "notes.md", "runtime@" + "sample.iam.gserviceaccount.com", true},
		{"AWS token", "notes.md", "AKIA" + strings.Repeat("A", 16), true},
		{"GitHub token", "notes.md", "ghp_" + strings.Repeat("a", 32), true},
		{"database URL", "notes.md", "postgresql" + "://user:password@database/db", true},
		{"binary", "image.bin", string([]byte{0, 1}), true},
		{"invalid UTF8", "text.txt", string([]byte{255}), true},
		{"lockfile allowed", ".terraform.lock.hcl", "# public dependency lock", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := Inspect(c.path, []byte(c.body))
			if (len(got) > 0) != c.want {
				t.Fatalf("finding presence: got %v, want %v", len(got) > 0, c.want)
			}
		})
	}
}

func TestFindingDoesNotContainMatchedValue(t *testing.T) {
	token := "ghp_" + strings.Repeat("b", 32)
	findings := Inspect("notes.md", []byte("line one\n"+token))
	if len(findings) != 1 || findings[0].Line != 2 {
		t.Fatal("expected one line-two finding")
	}
	if strings.Contains(fmt.Sprint(findings), token) {
		t.Fatal("finding leaked matched value")
	}
}

func TestScanTrackedFiles(t *testing.T) {
	root := t.TempDir()
	git := func(args ...string) {
		t.Helper()
		command := exec.Command("git", append([]string{"-C", root}, args...)...)
		if err := command.Run(); err != nil {
			t.Fatal("git fixture failed")
		}
	}
	git("init", "-q")
	if _, err := Scan(root); err == nil {
		t.Fatal("empty index must not be reported clean")
	}
	if err := os.WriteFile(filepath.Join(root, "README.md"), []byte("public description"), 0600); err != nil {
		t.Fatal(err)
	}
	git("add", "README.md")
	f, err := Scan(root)
	if err != nil || len(f) != 0 {
		t.Fatal("clean tracked file rejected")
	}
	ip := fmt.Sprintf("%d.%d.%d.%d", 192, 0, 2, 5)
	if err := os.WriteFile(filepath.Join(root, "README.md"), []byte(ip), 0600); err != nil {
		t.Fatal(err)
	}
	f, err = Scan(root)
	if err != nil || len(f) == 0 {
		t.Fatal("working-tree change was not detected")
	}
}
