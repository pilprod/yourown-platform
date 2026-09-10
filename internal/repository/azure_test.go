package repository

import (
	"fmt"
	"strings"
	"testing"
)

func TestAzureInventoryAndCredentials(t *testing.T) {
	guid := strings.Join([]string{strings.Repeat("a", 8), "bbbb", "cccc", "dddd", strings.Repeat("e", 12)}, "-")
	cases := map[string]string{
		"tenant":       `tenant_id = "` + guid + `"`,
		"subscription": "/subscriptions/" + guid + "/resourceGroups/private-group",
		"upper-client": strings.ToUpper(guid),
		"key-vault":    "https://sample." + "vault.azure.net/secrets/item",
		"blob-store":   "https://sample." + "blob.core.windows.net/private/config",
		"registry":     "sample." + "azurecr.io/image",
		"account-key":  "AccountKey=" + strings.Repeat("A", 32),
		"sas":          "?sv=test&sig=" + strings.Repeat("B", 32),
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			findings := Inspect("config.json", []byte(body))
			if len(findings) == 0 {
				t.Fatal("Azure inventory or credential not detected")
			}
			if strings.Contains(fmt.Sprint(findings), body) {
				t.Fatal("finding leaked matched value")
			}
		})
	}
	for _, body := range []string{"secret://sandbox/database", "config://sandbox/snapshot", "subscription_id = var.subscription_id", "https://learn.microsoft.com/en-us/entra/"} {
		if len(Inspect("example.json", []byte(body))) != 0 {
			t.Fatal("logical reference or official docs blocked")
		}
	}
}
