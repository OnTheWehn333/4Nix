package engine

import (
	"fmt"
	"strings"

	"github.com/OnTheWehn333/keysync/internal/config"
	"github.com/OnTheWehn333/keysync/internal/gpg"
	"github.com/OnTheWehn333/keysync/internal/op"
)

// BackupKey exports one top-level key and stores the full backup in 1Password.
func BackupKey(cfg *config.Config, keyName string) error {
	key, err := cfg.GetKey(keyName)
	if err != nil {
		return err
	}

	if err := op.EnsureSignedIn(); err != nil {
		return err
	}

	pubKey, err := gpg.ExportPublicKey(key.Fingerprint)
	if err != nil {
		return fmt.Errorf("failed to export public key for %s: %w", keyName, err)
	}

	secKey, err := gpg.ExportSecretKey(key.Fingerprint)
	if err != nil {
		return fmt.Errorf("failed to export secret key for %s: %w", keyName, err)
	}

	meta, err := gpg.ReadKeyMeta(key.Fingerprint)
	if err != nil {
		return fmt.Errorf("failed to read key metadata for %s: %w", keyName, err)
	}

	pubHash := sha256Hex(pubKey)
	secHash := sha256Hex(secKey)

	existing, err := op.GetItem(key.Title, cfg.Vault)
	if err != nil {
		return fmt.Errorf("failed to check 1Password item %q: %w", key.Title, err)
	}

	if existing != nil {
		if existing.FieldValue("sha256_public") == pubHash && existing.FieldValue("sha256_secret") == secHash {
			fmt.Printf("= %s unchanged\n", key.Title)
			return nil
		}
	}

	fields := op.ItemFields{
		Fingerprint:  key.Fingerprint,
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
		if err := op.EditItem(key.Title, cfg.Vault, fields); err != nil {
			return fmt.Errorf("failed to update 1Password item %q: %w", key.Title, err)
		}
		fmt.Printf("- %s updated\n", key.Title)
		return nil
	}

	if err := op.CreateItem(key.Title, cfg.Vault, fields); err != nil {
		return fmt.Errorf("failed to create 1Password item %q: %w", key.Title, err)
	}

	fmt.Printf("+ %s created\n", key.Title)
	return nil
}

// BackupAll exports all top-level keys and stores full backups in 1Password.
func BackupAll(cfg *config.Config) error {
	if err := op.EnsureSignedIn(); err != nil {
		return err
	}

	var failures []string
	for _, keyName := range cfg.AllKeyNames() {
		if err := BackupKey(cfg, keyName); err != nil {
			msg := fmt.Sprintf("%s: %v", keyName, err)
			failures = append(failures, msg)
			fmt.Printf("! %s\n", msg)
		}
	}

	if len(failures) > 0 {
		return fmt.Errorf("backup failures: %s", strings.Join(failures, "; "))
	}

	return nil
}

// BackupRestore restores one top-level full backup key from 1Password.
func BackupRestore(cfg *config.Config, keyName string, opts RestoreOpts) error {
	key, err := cfg.GetKey(keyName)
	if err != nil {
		return err
	}

	if err := op.EnsureSignedIn(); err != nil {
		return err
	}

	item, err := op.GetItem(key.Title, cfg.Vault)
	if err != nil {
		return fmt.Errorf("failed to fetch %s from 1Password: %w", key.Title, err)
	}
	if item == nil {
		return fmt.Errorf("1Password item %q not found in vault %q", key.Title, cfg.Vault)
	}

	publicKey := item.FieldValue("public_key")
	secretKey := item.FieldValue("secret_key")
	if publicKey == "" || secretKey == "" {
		return fmt.Errorf("1Password item %q is missing public_key or secret_key fields", key.Title)
	}

	if opts.VerifyHash && !opts.Force {
		storedPublicHash := item.FieldValue("sha256_public")
		storedSecretHash := item.FieldValue("sha256_secret")
		if storedPublicHash == "" || storedSecretHash == "" {
			return fmt.Errorf("1Password item %q is missing hash fields; use --force to skip verification", key.Title)
		}

		actualPublicHash := sha256Hex([]byte(publicKey))
		actualSecretHash := sha256Hex([]byte(secretKey))
		if actualPublicHash != storedPublicHash {
			return fmt.Errorf("sha256 mismatch on public_key for %q (stored: %s, actual: %s)", key.Title, storedPublicHash, actualPublicHash)
		}
		if actualSecretHash != storedSecretHash {
			return fmt.Errorf("sha256 mismatch on secret_key for %q (stored: %s, actual: %s)", key.Title, storedSecretHash, actualSecretHash)
		}
	}

	if opts.DryRun {
		fmt.Printf("would restore %s -> GPG keyring\n", key.Title)
		return nil
	}

	if opts.Force {
		if err := gpg.DeleteKey(key.Fingerprint); err != nil {
			return fmt.Errorf("failed to delete existing key %q: %w", key.Fingerprint, err)
		}
	}

	if err := gpg.ImportKey([]byte(publicKey)); err != nil {
		return fmt.Errorf("failed to import public_key for %q: %w", key.Title, err)
	}

	if err := gpg.ImportKey([]byte(secretKey)); err != nil {
		return fmt.Errorf("failed to import secret_key for %q: %w", key.Title, err)
	}

	fmt.Printf("restored %s -> GPG keyring\n", key.Title)
	return nil
}
