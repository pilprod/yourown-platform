package agentcontext

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func fixture(t *testing.T) (string, manifest) {
	t.Helper()
	root := t.TempDir()
	config := manifest{
		SchemaVersion: 1,
		Base:          selection{Rules: []string{"rag/rules/base.md"}, Knowledge: []string{"docs/base.md"}},
		Topics: map[string]selection{
			"general":   {Rules: []string{}, Knowledge: []string{}},
			"terraform": {Rules: []string{"rag/rules/base.md", "rag/rules/terraform.md"}, Knowledge: []string{"docs/base.md", "rag/knowledge/terraform.md"}},
		},
	}
	for _, name := range []string{"rag/rules/base.md", "docs/base.md", "rag/rules/terraform.md", "rag/knowledge/terraform.md"} {
		writeFile(t, root, name, []byte("Reviewed context: "+name+"\n"))
	}
	writeManifest(t, root, config)
	return root, config
}

func writeFile(t *testing.T, root, name string, data []byte) {
	t.Helper()
	full := filepath.Join(root, name)
	if err := os.MkdirAll(filepath.Dir(full), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(full, data, 0600); err != nil {
		t.Fatal(err)
	}
}

func writeManifest(t *testing.T, root string, config manifest) {
	t.Helper()
	data, err := json.Marshal(config)
	if err != nil {
		t.Fatal(err)
	}
	writeFile(t, root, manifestPath, data)
}

func TestLoadSelection(t *testing.T) {
	root, _ := fixture(t)
	for _, topic := range []string{"general", "terraform"} {
		t.Run(topic, func(t *testing.T) {
			bundle, err := Load(root, topic)
			if err != nil {
				t.Fatal(err)
			}
			wantRules := []string{"rag/rules/base.md"}
			wantKnowledge := []string{"docs/base.md"}
			if topic == "terraform" {
				wantRules = append(wantRules, "rag/rules/terraform.md")
				wantKnowledge = append(wantKnowledge, "rag/knowledge/terraform.md")
			}
			if bundle.SchemaVersion != 1 || bundle.Topic != topic {
				t.Fatal("bundle identity does not match the selection")
			}
			for _, group := range []struct {
				docs  []Document
				paths []string
			}{{bundle.Rules, wantRules}, {bundle.Knowledge, wantKnowledge}} {
				var paths []string
				for _, doc := range group.docs {
					paths = append(paths, doc.Path)
					want := "Reviewed context: " + doc.Path + "\n"
					digest := sha256.Sum256([]byte(want))
					if doc.Content != want || doc.SHA256 != hex.EncodeToString(digest[:]) {
						t.Fatal("source content or digest changed")
					}
				}
				if !reflect.DeepEqual(paths, group.paths) {
					t.Fatal("selection, order, role separation or deduplication is incorrect")
				}
			}
		})
	}
}

func TestLoadRejectsInvalidSelection(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*manifest)
	}{
		{"version", func(m *manifest) { m.SchemaVersion = 2 }},
		{"missing rules", func(m *manifest) { m.Base.Rules = nil }},
		{"empty mandatory rules", func(m *manifest) { m.Base.Rules = []string{} }},
		{"null knowledge", func(m *manifest) { m.Base.Knowledge = nil }},
		{"missing topics", func(m *manifest) { m.Topics = nil }},
		{"null topic", func(m *manifest) { m.Topics["general"] = selection{} }},
		{"empty topic name", func(m *manifest) { m.Topics[""] = selection{Rules: []string{}, Knowledge: []string{}} }},
		{"traversal", func(m *manifest) { m.Base.Rules = []string{"rag/rules/../../private.md"} }},
		{"unclean", func(m *manifest) { m.Base.Rules = []string{"rag/rules/./base.md"} }},
		{"absolute", func(m *manifest) { m.Base.Rules = []string{"/rag/rules/base.md"} }},
		{"backslash", func(m *manifest) { m.Base.Rules = []string{"rag/rules/a\\b.md"} }},
		{"rule not Markdown", func(m *manifest) { m.Base.Rules = []string{"rag/rules/base.txt"} }},
		{"rule outside trusted directory", func(m *manifest) { m.Base.Rules = []string{"docs/base.md"} }},
		{"knowledge outside allowed directory", func(m *manifest) { m.Base.Knowledge = []string{"README.md"} }},
		{"knowledge not Markdown", func(m *manifest) { m.Base.Knowledge = []string{"terraform/main.tf"} }},
		{"cross role", func(m *manifest) { m.Base.Knowledge = []string{"rag/rules/base.md"} }},
		{"invalid unused topic", func(m *manifest) {
			m.Topics["unused"] = selection{Rules: []string{"../private.md"}, Knowledge: []string{}}
		}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			root, config := fixture(t)
			tc.mutate(&config)
			writeManifest(t, root, config)
			assertRejected(t, root, "general")
		})
	}
	root, _ := fixture(t)
	assertRejected(t, root, "unknown")
}

func TestLoadRejectsCorruptManifest(t *testing.T) {
	cases := []string{
		`{`, `null`, `[]`,
		`{"schema_version":1,"schema_version":1}`,
		`{"schema_version":1,"base":{"rules":[],"rules":[]}}`,
	}
	for _, body := range cases {
		root, _ := fixture(t)
		writeFile(t, root, manifestPath, []byte(body))
		assertRejected(t, root, "general")
	}
	for _, suffix := range []string{`,"unexpected":true}`, `,"schema_version":1}`, `} {}`} {
		root, config := fixture(t)
		data, err := json.Marshal(config)
		if err != nil {
			t.Fatal(err)
		}
		writeFile(t, root, manifestPath, append(data[:len(data)-1], suffix...))
		assertRejected(t, root, "general")
	}
}

func TestLoadRejectsUnavailableOrPrivateInputs(t *testing.T) {
	for _, name := range []string{manifestPath, "rag/rules/base.md", "docs/base.md", "rag/rules/terraform.md"} {
		t.Run("missing "+name, func(t *testing.T) {
			root, _ := fixture(t)
			if err := os.Remove(filepath.Join(root, name)); err != nil {
				t.Fatal(err)
			}
			assertRejected(t, root, "terraform")
		})
	}
	for _, name := range []string{"rag/rules/base.md", "rag/rules/terraform.md", "docs/base.md"} {
		for _, body := range []string{"", " \n\r\t"} {
			root, _ := fixture(t)
			writeFile(t, root, name, []byte(body))
			assertRejected(t, root, "terraform")
		}
	}
	private := "ghp_" + strings.Repeat("a", 32)
	for _, body := range [][]byte{[]byte(private), {0}, {1}, {255}, []byte(strings.Repeat("x", maxFileBytes+1))} {
		root, _ := fixture(t)
		writeFile(t, root, "docs/base.md", body)
		assertRejected(t, root, "general")
	}
	root, config := fixture(t)
	config.Base.Rules = []string{"rag/rules/.env.private.md"}
	writeFile(t, root, config.Base.Rules[0], []byte("Private artifact names remain prohibited."))
	writeManifest(t, root, config)
	assertRejected(t, root, "general")
}

func TestLoadRejectsSymlinksAndDirectories(t *testing.T) {
	for _, name := range []string{manifestPath, "rag/rules/base.md", "rag/rules", "rag"} {
		t.Run(name, func(t *testing.T) {
			root, _ := fixture(t)
			source := filepath.Join(root, name)
			destination := source + ".original"
			if err := os.Rename(source, destination); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(destination, source); err != nil {
				t.Fatal(err)
			}
			assertRejected(t, root, "general")
		})
	}
	root, _ := fixture(t)
	file := filepath.Join(root, "docs/base.md")
	if err := os.Remove(file); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(file, 0700); err != nil {
		t.Fatal(err)
	}
	assertRejected(t, root, "general")
}

func TestLoadRejectsAggregateOverflow(t *testing.T) {
	root, config := fixture(t)
	config.Base.Knowledge = []string{}
	for _, name := range []string{"one", "two", "three", "four"} {
		path := "docs/" + name + ".md"
		config.Base.Knowledge = append(config.Base.Knowledge, path)
		writeFile(t, root, path, []byte(strings.Repeat("x", maxFileBytes)))
	}
	writeManifest(t, root, config)
	assertRejected(t, root, "general")
}

func assertRejected(t *testing.T, root, topic string) {
	t.Helper()
	bundle, err := Load(root, topic)
	if err == nil || !reflect.DeepEqual(bundle, Bundle{}) {
		t.Fatal("invalid input produced a complete or partial context bundle")
	}
	if err.Error() != errInvalid.Error() {
		t.Fatal("failure exposed input details")
	}
}
