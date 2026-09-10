// Package contracts validates the public, reference-only platform vocabulary.
// It neither resolves private references nor generates/applies Terraform.
package contracts

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"reflect"
	"regexp"
	"strings"
	"unicode/utf8"
)

const Version = "platform.yourown/v1alpha1"
const MaxBytes = 1024 * 1024

// Error carries only a fixed rule, never an input value or caller-supplied key.
type Error struct{ Rule string }

func (e Error) Error() string  { return "contract rejected: " + e.Rule }
func reject(rule string) error { return Error{Rule: rule} }

type SnapshotReference struct {
	Ref    string `json:"ref"`
	SHA256 string `json:"sha256"`
}
type Environment struct {
	APIVersion    string            `json:"apiVersion"`
	Kind          string            `json:"kind"`
	Name          string            `json:"name"`
	Provider      string            `json:"provider"`
	Runtime       string            `json:"runtime"`
	Configuration SnapshotReference `json:"configuration"`
}
type Image struct {
	RepositoryRef string `json:"repositoryRef"`
	Digest        string `json:"digest"`
}
type SecretReference struct {
	Name    string `json:"name"`
	Ref     string `json:"ref"`
	Version string `json:"version"`
}
type Workload struct {
	APIVersion     string            `json:"apiVersion"`
	Kind           string            `json:"kind"`
	Name           string            `json:"name"`
	EnvironmentRef string            `json:"environmentRef"`
	Image          Image             `json:"image"`
	Secrets        []SecretReference `json:"secrets"`
}
type Release struct {
	APIVersion          string `json:"apiVersion"`
	Kind                string `json:"kind"`
	WorkloadRef         string `json:"workloadRef"`
	EnvironmentRef      string `json:"environmentRef"`
	ImageDigest         string `json:"imageDigest"`
	ConfigurationSHA256 string `json:"configurationSHA256"`
	SourceCommit        string `json:"sourceCommit"`
}
type SecretDocument struct {
	APIVersion string          `json:"apiVersion"`
	Kind       string          `json:"kind"`
	Secret     SecretReference `json:"secret"`
}

var nameRE = regexp.MustCompile(`^[a-z][a-z0-9-]{0,62}$`)
var hashRE = regexp.MustCompile(`^[a-f0-9]{64}$`)
var digestRE = regexp.MustCompile(`^sha256:[a-f0-9]{64}$`)
var commitRE = regexp.MustCompile(`^[a-f0-9]{40}$`)
var versionRE = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`)

func reference(s, scheme string, parts int) bool {
	if !strings.HasPrefix(s, scheme+"://") {
		return false
	}
	fields := strings.Split(strings.TrimPrefix(s, scheme+"://"), "/")
	if len(fields) != parts {
		return false
	}
	for _, f := range fields {
		if !nameRE.MatchString(f) {
			return false
		}
	}
	return true
}
func secretValid(s SecretReference) bool {
	switch strings.ToLower(s.Version) {
	case "latest", "current", "awscurrent", "awsprevious":
		return false
	}
	return nameRE.MatchString(s.Name) && reference(s.Ref, "secret", 2) && versionRE.MatchString(s.Version)
}

// Validate rejects unknown/missing fields, duplicate keys, case aliases, null,
// excessive nesting and trailing documents before applying semantic constraints.
func Validate(data []byte) (any, error) {
	if len(data) == 0 || len(data) > MaxBytes || !utf8.Valid(data) {
		return nil, reject("document-size-or-encoding")
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	if err := walk(decoder, 0); err != nil {
		return nil, reject("invalid-or-ambiguous-json")
	}
	if _, err := decoder.Token(); !errors.Is(err, io.EOF) {
		return nil, reject("trailing-json")
	}
	var header struct {
		APIVersion string `json:"apiVersion"`
		Kind       string `json:"kind"`
	}
	if json.Unmarshal(data, &header) != nil || header.APIVersion != Version {
		return nil, reject("api-version")
	}
	var doc any
	switch header.Kind {
	case "Environment":
		doc = &Environment{}
	case "Workload":
		doc = &Workload{}
	case "Release":
		doc = &Release{}
	case "SecretReference":
		doc = &SecretDocument{}
	default:
		return nil, reject("document-kind")
	}
	if !shape(data, reflect.TypeOf(doc).Elem()) || json.Unmarshal(data, doc) != nil {
		return nil, reject("document-shape")
	}
	switch v := doc.(type) {
	case *Environment:
		validRuntime := v.Provider == "gcp" && (v.Runtime == "cloud-run" || v.Runtime == "gke") || v.Provider == "aws" && (v.Runtime == "ecs" || v.Runtime == "eks")
		if !nameRE.MatchString(v.Name) || !validRuntime || !reference(v.Configuration.Ref, "config", 2) || !hashRE.MatchString(v.Configuration.SHA256) {
			return nil, reject("environment-policy")
		}
	case *Workload:
		if !nameRE.MatchString(v.Name) || !reference(v.EnvironmentRef, "environment", 1) || !reference(v.Image.RepositoryRef, "artifact", 1) || !digestRE.MatchString(v.Image.Digest) || len(v.Secrets) > 32 {
			return nil, reject("workload-policy")
		}
		seen := map[string]bool{}
		for _, s := range v.Secrets {
			if !secretValid(s) || seen[s.Name] {
				return nil, reject("secret-reference-policy")
			}
			seen[s.Name] = true
		}
	case *Release:
		if !reference(v.WorkloadRef, "workload", 1) || !reference(v.EnvironmentRef, "environment", 1) || !digestRE.MatchString(v.ImageDigest) || !hashRE.MatchString(v.ConfigurationSHA256) || !commitRE.MatchString(v.SourceCommit) {
			return nil, reject("release-policy")
		}
	case *SecretDocument:
		if !secretValid(v.Secret) {
			return nil, reject("secret-reference-policy")
		}
	}
	return doc, nil
}

// walk checks duplicate keys after JSON unescaping; encoding/json alone accepts them.
func walk(d *json.Decoder, depth int) error {
	if depth > 32 {
		return reject("depth")
	}
	token, err := d.Token()
	if err != nil {
		return err
	}
	if token == nil {
		return reject("null")
	}
	delim, ok := token.(json.Delim)
	if !ok {
		return nil
	}
	switch delim {
	case '{':
		keys := map[string]bool{}
		for d.More() {
			key, err := d.Token()
			if err != nil {
				return err
			}
			name, ok := key.(string)
			if !ok || keys[name] {
				return reject("duplicate-key")
			}
			keys[name] = true
			if err := walk(d, depth+1); err != nil {
				return err
			}
		}
	case '[':
		for d.More() {
			if err := walk(d, depth+1); err != nil {
				return err
			}
		}
	default:
		return reject("delimiter")
	}
	end, err := d.Token()
	if err != nil {
		return err
	}
	if delim == '{' && end != json.Delim('}') || delim == '[' && end != json.Delim(']') {
		return reject("delimiter")
	}
	return nil
}

// shape enforces exact JSON tags, including required nested fields. Go's default
// decoder accepts case-insensitive aliases; that behavior is inappropriate here.
func shape(raw []byte, typ reflect.Type) bool {
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return false
	}
	switch typ.Kind() {
	case reflect.Struct:
		var fields map[string]json.RawMessage
		if json.Unmarshal(raw, &fields) != nil || len(fields) != typ.NumField() {
			return false
		}
		for i := 0; i < typ.NumField(); i++ {
			f := typ.Field(i)
			v, ok := fields[f.Tag.Get("json")]
			if !ok || !shape(v, f.Type) {
				return false
			}
		}
	case reflect.Slice:
		var values []json.RawMessage
		if json.Unmarshal(raw, &values) != nil {
			return false
		}
		for _, v := range values {
			if !shape(v, typ.Elem()) {
				return false
			}
		}
	case reflect.String:
		var s string
		if json.Unmarshal(raw, &s) != nil {
			return false
		}
	default:
		return false
	}
	return true
}

// VerifySnapshot binds the exact bytes to an already validated Environment.
// It does not fetch objects, authenticate the manifest, or ensure that a later
// Terraform run consumes those same bytes. Those are private runner obligations.
func VerifySnapshot(environment []byte, snapshot io.Reader) error {
	doc, err := Validate(environment)
	if err != nil {
		return err
	}
	env, ok := doc.(*Environment)
	if !ok {
		return reject("environment-required")
	}
	data, err := io.ReadAll(io.LimitReader(snapshot, MaxBytes+1))
	if err != nil || len(data) == 0 || len(data) > MaxBytes || !utf8.Valid(data) || !json.Valid(data) {
		return reject("snapshot-read-or-json")
	}
	sum := sha256.Sum256(data)
	if hex.EncodeToString(sum[:]) != env.Configuration.SHA256 {
		return reject("snapshot-digest")
	}
	return nil
}
