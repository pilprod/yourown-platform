package contracts

import (
	"bytes"
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

func TestProviderRuntimeMatrix(t *testing.T) {
	allowed := map[string]map[string]bool{
		"gcp":   {"cloud-run": true, "gke": true},
		"aws":   {"ecs": true, "eks": true},
		"azure": {"container-apps": true, "aks": true},
	}
	for _, provider := range []string{"gcp", "aws", "azure", "Azure", "other"} {
		for _, runtime := range []string{"cloud-run", "gke", "ecs", "eks", "container-apps", "aks", "unknown"} {
			t.Run(provider+"/"+runtime, func(t *testing.T) {
				var env Environment
				if err := json.Unmarshal(example(t, "azure-environment"), &env); err != nil {
					t.Fatal(err)
				}
				env.Provider, env.Runtime = provider, runtime
				_, err := Validate(mustMarshal(t, env))
				if (err == nil) != allowed[provider][runtime] {
					t.Fatal("provider/runtime policy mismatch")
				}
			})
		}
	}
}

func TestAzurePrivateValuesRejected(t *testing.T) {
	for _, field := range []string{"tenantId", "subscriptionId", "clientId", "clientSecret", "vaultUrl"} {
		t.Run(field, func(t *testing.T) {
			var env map[string]any
			if err := json.Unmarshal(example(t, "azure-environment"), &env); err != nil {
				t.Fatal(err)
			}
			env[field] = "private-value-do-not-echo"
			_, err := Validate(mustMarshal(t, env))
			var safe Error
			if !errors.As(err, &safe) || strings.Contains(err.Error(), "private-value-do-not-echo") {
				t.Fatal("unsafe or missing rejection")
			}
		})
	}
}

func TestAzureSnapshotAndSecretReferences(t *testing.T) {
	snapshot := example(t, "synthetic-snapshot")
	for _, name := range []string{"azure-environment", "azure-aks-environment"} {
		if err := VerifySnapshot(example(t, name), bytes.NewReader(snapshot)); err != nil {
			t.Fatal(err)
		}
	}
	var secret SecretDocument
	if err := json.Unmarshal(example(t, "azure-secret-reference"), &secret); err != nil {
		t.Fatal(err)
	}
	for _, version := range []string{"latest", "LATEST", "current", ""} {
		copy := secret
		copy.Secret.Version = version
		if _, err := Validate(mustMarshal(t, copy)); err == nil {
			t.Fatal("floating or missing version accepted")
		}
	}
	// Resolve native provider identifiers only from private configuration.
	secret.Secret.Ref = "https://example.invalid/secrets/database/version"
	if _, err := Validate(mustMarshal(t, secret)); err == nil {
		t.Fatal("native URI accepted as a logical reference")
	}
}
