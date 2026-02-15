package engine

import (
	"crypto/sha256"
	"fmt"
	"sort"
	"strings"

	"github.com/OnTheWehn333/keysync/internal/config"
	"github.com/OnTheWehn333/keysync/internal/gpg"
	"github.com/OnTheWehn333/keysync/internal/op"
)

// SyncHost syncs all key references for one host to 1Password.
func SyncHost(cfg *config.Config, hostName string) error {
	host, err := cfg.GetHost(hostName)
	if err != nil {
		return err
	}

	if err := op.EnsureSignedIn(); err != nil {
		return err
	}

	for _, ref := range host.Keys {
		if err := syncRef(cfg, ref); err != nil {
			return err
		}
	}

	return nil
}

// SyncAll syncs all unique key references across all hosts to 1Password.
func SyncAll(cfg *config.Config) error {
	if err := op.EnsureSignedIn(); err != nil {
		return err
	}

	unique := make(map[string]struct{})
	for _, host := range cfg.Hosts {
		for _, ref := range host.Keys {
			unique[ref] = struct{}{}
		}
	}

	refs := make([]string, 0, len(unique))
	for ref := range unique {
		refs = append(refs, ref)
	}
	sort.Strings(refs)

	var failures []string
	for _, ref := range refs {
		if err := syncRef(cfg, ref); err != nil {
			msg := fmt.Sprintf("%s: %v", ref, err)
			failures = append(failures, msg)
			fmt.Printf("! %s\n", msg)
		}
	}

	if len(failures) > 0 {
		return fmt.Errorf("sync failures: %s", strings.Join(failures, "; "))
	}

	return nil
}

func syncRef(cfg *config.Config, ref string) error {
	resolved, err := cfg.ResolveRef(ref)
	if err != nil {
		return err
	}

	pubKey, err := gpg.ExportPublicKey(resolved.ParentFP)
	if err != nil {
		return fmt.Errorf("failed to export public key for %s: %w", ref, err)
	}

	secKey, err := gpg.ExportSecretSubkey(resolved.Fingerprint)
	if err != nil {
		return fmt.Errorf("failed to export secret subkey for %s: %w", ref, err)
	}

	meta, err := gpg.ReadKeyMeta(resolved.ParentFP)
	if err != nil {
		return fmt.Errorf("failed to read key metadata for %s: %w", ref, err)
	}

	pubHash := sha256Hex(pubKey)
	secHash := sha256Hex(secKey)

	existing, err := op.GetItem(resolved.ItemTitle, cfg.Vault)
	if err != nil {
		return fmt.Errorf("failed to check 1Password item %q: %w", resolved.ItemTitle, err)
	}

	if existing != nil {
		existingPubHash := existing.FieldValue("sha256_public")
		existingSecHash := existing.FieldValue("sha256_secret")
		if existingPubHash == pubHash && existingSecHash == secHash {
			fmt.Printf("= %s unchanged\n", resolved.ItemTitle)
			return nil
		}
	}

	fields := op.ItemFields{
		Fingerprint:  resolved.Fingerprint,
		Algorithm:    meta.Algorithm,
		Capabilities: meta.Capabilities,
		UID:          meta.UID,
		Created:      meta.Created,
		Expires:      meta.Expires,
		PublicKey:    string(pubKey),
		SecretKey:    string(secKey),
		SHA256Public: pubHash,
		SHA256Secret: secHash,
	}

	if existing != nil {
		if err := op.EditItem(resolved.ItemTitle, cfg.Vault, fields); err != nil {
			return fmt.Errorf("failed to update 1Password item %q: %w", resolved.ItemTitle, err)
		}
		fmt.Printf("- %s updated\n", resolved.ItemTitle)
		return nil
	}

	if err := op.CreateItem(resolved.ItemTitle, cfg.Vault, fields); err != nil {
		return fmt.Errorf("failed to create 1Password item %q: %w", resolved.ItemTitle, err)
	}

	fmt.Printf("+ %s created\n", resolved.ItemTitle)
	return nil
}

func sha256Hex(data []byte) string {
	h := sha256.Sum256(data)
	return fmt.Sprintf("%x", h)
}
