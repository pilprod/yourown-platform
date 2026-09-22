// Package agentcontext builds explicit, provider-neutral context from reviewed
// repository documents. It does not retrieve remote content or enforce policy.
package agentcontext

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"
	"unicode"

	"github.com/pilprod/yourown-platform/internal/repository"
)

const (
	manifestPath  = "rag/manifest.json"
	maxFileBytes  = 64 * 1024
	maxTotalBytes = 256 * 1024
)

var errInvalid = errors.New("context configuration or input is invalid or unavailable")

type selection struct {
	Rules     []string `json:"rules"`
	Knowledge []string `json:"knowledge"`
}

type manifest struct {
	SchemaVersion int                  `json:"schema_version"`
	Base          selection            `json:"base"`
	Topics        map[string]selection `json:"topics"`
}

// Document preserves its source path and a digest of the exact UTF-8 bytes.
type Document struct {
	Path    string `json:"path"`
	SHA256  string `json:"sha256"`
	Content string `json:"content"`
}

// Bundle keeps mandatory instructions distinct from supporting knowledge.
type Bundle struct {
	SchemaVersion int        `json:"schema_version"`
	Topic         string     `json:"topic"`
	Rules         []Document `json:"rules"`
	Knowledge     []Document `json:"knowledge"`
}

// Load reads the base selection and one explicitly selected topic. It returns no
// bundle if any selected input is invalid, private, inaccessible, or too large.
func Load(root, topic string) (Bundle, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return Bundle{}, errInvalid
	}
	// Resolve OS aliases on the supplied root; no links below it are accepted.
	root, err = filepath.EvalSymlinks(root)
	if err != nil {
		return Bundle{}, errInvalid
	}
	data, err := readDocument(root, manifestPath)
	if err != nil {
		return Bundle{}, errInvalid
	}
	if err := uniqueJSON(json.NewDecoder(bytes.NewReader(data)), 0); err != nil {
		return Bundle{}, errInvalid
	}
	var config manifest
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&config); err != nil {
		return Bundle{}, errInvalid
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return Bundle{}, errInvalid
	}
	if config.SchemaVersion != 1 || config.Topics == nil || len(config.Base.Rules) == 0 {
		return Bundle{}, errInvalid
	}
	roles := map[string]string{}
	validate := func(s selection) bool {
		if s.Rules == nil || s.Knowledge == nil {
			return false
		}
		for role, paths := range map[string][]string{"rules": s.Rules, "knowledge": s.Knowledge} {
			for _, name := range paths {
				if !validPath(name, role) || (roles[name] != "" && roles[name] != role) {
					return false
				}
				roles[name] = role
			}
		}
		return true
	}
	if !validate(config.Base) {
		return Bundle{}, errInvalid
	}
	for name, s := range config.Topics {
		if name == "" || !validate(s) {
			return Bundle{}, errInvalid
		}
	}
	selected, ok := config.Topics[topic]
	if !ok {
		return Bundle{}, errInvalid
	}
	bundle := Bundle{SchemaVersion: 1, Topic: topic, Rules: []Document{}, Knowledge: []Document{}}
	total := len(data)
	seen := map[string]bool{}
	appendDocuments := func(paths []string, target *[]Document) error {
		for _, name := range paths {
			if seen[name] {
				continue
			}
			content, err := readDocument(root, name)
			if err != nil || total+len(content) > maxTotalBytes {
				return errInvalid
			}
			total += len(content)
			digest := sha256.Sum256(content)
			*target = append(*target, Document{Path: name, SHA256: hex.EncodeToString(digest[:]), Content: string(content)})
			seen[name] = true
		}
		return nil
	}
	for _, s := range []selection{config.Base, selected} {
		if err := appendDocuments(s.Rules, &bundle.Rules); err != nil {
			return Bundle{}, errInvalid
		}
		if err := appendDocuments(s.Knowledge, &bundle.Knowledge); err != nil {
			return Bundle{}, errInvalid
		}
	}
	return bundle, nil
}

func validPath(name, role string) bool {
	if name == "" || path.IsAbs(name) || path.Clean(name) != name || strings.Contains(name, "\\") || strings.Contains(name, ":") {
		return false
	}
	for _, part := range strings.Split(name, "/") {
		if part == "." || part == ".." {
			return false
		}
	}
	if path.Ext(name) != ".md" {
		return false
	}
	if role == "rules" {
		return strings.HasPrefix(name, "rag/rules/")
	}
	for _, prefix := range []string{"rag/knowledge/", "docs/", "terraform/", "runtime/"} {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	return false
}

func readDocument(root, name string) ([]byte, error) {
	current := root
	parts := strings.Split(name, "/")
	var info os.FileInfo
	for i, part := range parts {
		current = filepath.Join(current, part)
		var err error
		info, err = os.Lstat(current)
		if err != nil || info.Mode()&os.ModeSymlink != 0 {
			return nil, errInvalid
		}
		if i < len(parts)-1 && !info.IsDir() {
			return nil, errInvalid
		}
	}
	if !info.Mode().IsRegular() || info.Size() > maxFileBytes {
		return nil, errInvalid
	}
	file, err := os.Open(current)
	if err != nil {
		return nil, errInvalid
	}
	defer file.Close()
	opened, err := file.Stat()
	if err != nil || !os.SameFile(info, opened) || !opened.Mode().IsRegular() {
		return nil, errInvalid
	}
	data, err := io.ReadAll(io.LimitReader(file, maxFileBytes+1))
	if err != nil || len(data) > maxFileBytes || len(bytes.TrimSpace(data)) == 0 || len(repository.Inspect(name, data)) != 0 {
		return nil, errInvalid
	}
	for _, r := range string(data) {
		if unicode.IsControl(r) && r != '\n' && r != '\r' && r != '\t' {
			return nil, errInvalid
		}
	}
	return data, nil
}

// encoding/json permits duplicate object keys by default. Reject them so no
// parser can silently choose a different rule selection from the same manifest.
func uniqueJSON(decoder *json.Decoder, depth int) error {
	if depth > 32 {
		return errInvalid
	}
	token, err := decoder.Token()
	if err != nil {
		return errInvalid
	}
	delim, ok := token.(json.Delim)
	if !ok {
		return nil
	}
	keys := map[string]bool{}
	for decoder.More() {
		if delim == '{' {
			key, err := decoder.Token()
			name, ok := key.(string)
			if err != nil || !ok || keys[name] {
				return errInvalid
			}
			keys[name] = true
		}
		if err := uniqueJSON(decoder, depth+1); err != nil {
			return err
		}
	}
	_, err = decoder.Token()
	return err
}
