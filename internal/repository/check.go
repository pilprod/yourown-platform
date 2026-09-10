package repository

import (
	"bytes"
	"context"
	"fmt"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

type Finding struct {
	Path string
	Line int
	Rule string
}

type rule struct {
	name    string
	pattern *regexp.Regexp
}

var patterns = []rule{
	{"private-key", regexp.MustCompile(`-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----`)},
	{"cloud-account-number", regexp.MustCompile(`\b[0-9]{12,13}\b`)},
	{"service-account-address", regexp.MustCompile(`[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.iam\.gserviceaccount\.com`)},
	{"aws-access-key", regexp.MustCompile(`\b(?:AKIA|ASIA)[A-Z0-9]{16}\b`)},
	{"github-token", regexp.MustCompile(`\bgh[pousr]_[A-Za-z0-9]{20,}\b`)},
	{"credentialed-database-url", regexp.MustCompile(`(?i)(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?)://[^\s/:@]+:[^\s@]+@`)},
}

var addressTokens = regexp.MustCompile(`[0-9A-Fa-f:.%_-]+(?:/[0-9]+)?`)

// Scan reads tracked working-tree files, not blobs in the index or history.
// It refuses incomplete or non-text input rather than reporting a clean scan.
func Scan(root string) ([]Finding, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", root, "ls-files", "--cached", "-z", "--", ".")
	data, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("list tracked files: %w", err)
	}
	if len(data) == 0 {
		return nil, fmt.Errorf("no tracked files; stage intended files first")
	}
	var findings []Finding
	for _, name := range strings.Split(string(data), "\x00") {
		if name == "" {
			continue
		}
		clean := filepath.Clean(name)
		if filepath.IsAbs(clean) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
			return nil, fmt.Errorf("invalid tracked path")
		}
		path := filepath.Join(root, clean)
		info, err := os.Lstat(path)
		if err != nil {
			return nil, fmt.Errorf("cannot inspect tracked file")
		}
		if !info.Mode().IsRegular() || info.Size() > 1024*1024 {
			findings = append(findings, Finding{name, 1, "non-regular-or-oversized-file"})
			continue
		}
		content, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("cannot read tracked file")
		}
		findings = append(findings, Inspect(name, content)...)
	}
	return findings, nil
}

func Inspect(path string, content []byte) []Finding {
	var out []Finding
	name := strings.ToLower(filepath.Base(path))
	if forbiddenName(name) {
		out = append(out, Finding{path, 1, "private-or-generated-artifact"})
	}
	if !utf8.Valid(content) || bytes.IndexByte(content, 0) >= 0 {
		return append(out, Finding{path, 1, "non-text-content"})
	}
	for i, line := range strings.Split(string(content), "\n") {
		for _, r := range patterns {
			if r.pattern.MatchString(line) {
				out = append(out, Finding{path, i + 1, r.name})
			}
		}
		if containsAddress(line) {
			out = append(out, Finding{path, i + 1, "literal-ip-or-cidr"})
		}
	}
	return out
}

func forbiddenName(name string) bool {
	if name == ".env" || strings.HasPrefix(name, ".env.") || strings.Contains(name, ".tfstate") || strings.HasPrefix(name, "kubeconfig") || name == "credentials.json" || name == "application_default_credentials.json" {
		return true
	}
	for _, suffix := range []string{".tfvars", ".tfvars.json", ".tfplan", ".plan", ".pem", ".key", ".p12", ".pfx", ".dump", ".sqlite", ".zip", ".tar.gz"} {
		if strings.HasSuffix(name, suffix) {
			return true
		}
	}
	return false
}

func containsAddress(line string) bool {
	for _, token := range addressTokens.FindAllString(line, -1) {
		token = strings.Trim(token, ".")
		if _, err := netip.ParseAddr(token); err == nil {
			return true
		}
		if _, err := netip.ParsePrefix(token); err == nil {
			return true
		}
	}
	return false
}
