package op

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// Item represents a 1Password item.
type Item struct {
	ID     string  `json:"id"`
	Title  string  `json:"title"`
	Fields []Field `json:"fields"`
}

// Field represents a 1Password item field.
type Field struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	Value   string `json:"value"`
	Type    string `json:"type"`
	Purpose string `json:"purpose,omitempty"`
}

// ItemFields contains the key payload and metadata stored in 1Password.
type ItemFields struct {
	Fingerprint  string
	Algorithm    string
	Capabilities string
	UID          string
	Created      string
	Expires      string
	PublicKey    string
	SecretKey    string
	SHA256Public string
	SHA256Secret string
	SyncedAt     string
}

// FieldValue returns the value of the first field matching the given label.
func (item *Item) FieldValue(label string) string {
	for _, f := range item.Fields {
		if f.Label == label {
			return f.Value
		}
	}
	return ""
}

func opCmd(args ...string) *exec.Cmd {
	cmd := exec.Command("op", args...)
	cmd.Stdin = nil
	cmd.Env = append(cmd.Environ(), "OP_NO_PROMPT=1")
	return cmd
}

// EnsureSignedIn verifies the 1Password CLI has an active signed-in account.
func EnsureSignedIn() error {
	cmd := opCmd("whoami", "--format", "json")

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("1Password CLI not signed in. Sign in first:\n  eval $(op signin)\nor enable desktop app integration:\n  https://developer.1password.com/docs/cli/app-integration/")
	}

	return nil
}

// GetItem fetches an item by title and vault.
func GetItem(title, vault string) (*Item, error) {
	cmd := opCmd("item", "get", title,
		"--vault", vault,
		"--format", "json",
		"--reveal",
	)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		errMsg := strings.TrimSpace(stderr.String())
		if strings.Contains(strings.ToLower(errMsg), "not found") ||
			strings.Contains(strings.ToLower(errMsg), "isn't an item") {
			return nil, nil
		}
		return nil, fmt.Errorf("op item get failed: %s: %w", errMsg, err)
	}

	var item Item
	if err := json.Unmarshal(stdout.Bytes(), &item); err != nil {
		return nil, fmt.Errorf("failed to parse op output: %w", err)
	}

	return &item, nil
}

// CreateItem creates a new 1Password item with the provided fields.
func CreateItem(title, vault string, fields ItemFields) error {
	args := []string{
		"item", "create",
		"--category", "Secure Note",
		"--vault", vault,
		"--title", title,
		"--tags", "keysync",
	}
	args = append(args, fieldAssignments(fields)...)

	cmd := opCmd(args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("op item create failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}
	return nil
}

// EditItem updates an existing 1Password item with the provided fields.
func EditItem(title, vault string, fields ItemFields) error {
	args := []string{
		"item", "edit", title,
		"--vault", vault,
	}
	args = append(args, fieldAssignments(fields)...)

	cmd := opCmd(args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("op item edit failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}
	return nil
}

func fieldAssignments(f ItemFields) []string {
	now := f.SyncedAt
	if now == "" {
		now = time.Now().UTC().Format(time.RFC3339)
	}

	return []string{
		fmt.Sprintf("fingerprint[text]=%s", f.Fingerprint),
		fmt.Sprintf("algorithm[text]=%s", f.Algorithm),
		fmt.Sprintf("capabilities[text]=%s", f.Capabilities),
		fmt.Sprintf("uid[text]=%s", f.UID),
		fmt.Sprintf("created[text]=%s", f.Created),
		fmt.Sprintf("expires[text]=%s", f.Expires),
		fmt.Sprintf("public_key[text]=%s", f.PublicKey),
		fmt.Sprintf("secret_key[concealed]=%s", f.SecretKey),
		fmt.Sprintf("sha256_public[text]=%s", f.SHA256Public),
		fmt.Sprintf("sha256_secret[text]=%s", f.SHA256Secret),
		fmt.Sprintf("synced_at[text]=%s", now),
	}
}
