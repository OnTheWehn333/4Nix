package engine

import (
	"fmt"

	"github.com/OnTheWehn333/keysync/internal/config"
	"github.com/OnTheWehn333/keysync/internal/gpg"
	"github.com/OnTheWehn333/keysync/internal/op"
)

// RestoreOpts controls restore behavior.
type RestoreOpts struct {
	DryRun     bool
	Force      bool
	VerifyHash bool
}

// Restore restores all keys for a configured host from 1Password into the GPG keyring.
func Restore(cfg *config.Config, hostName string, opts RestoreOpts) error {
	host, err := cfg.GetHost(hostName)
	if err != nil {
		return err
	}

	if err := op.EnsureSignedIn(); err != nil {
		return err
	}

	for _, ref := range host.Keys {
		resolved, err := cfg.ResolveRef(ref)
		if err != nil {
			return err
		}

		item, err := op.GetItem(resolved.ItemTitle, cfg.Vault)
		if err != nil {
			return fmt.Errorf("failed to fetch %s from 1Password: %w", resolved.ItemTitle, err)
		}
		if item == nil {
			return fmt.Errorf("1Password item %q not found in vault %q", resolved.ItemTitle, cfg.Vault)
		}

		publicKey := item.FieldValue("public_key")
		secretKey := item.FieldValue("secret_key")
		if publicKey == "" || secretKey == "" {
			return fmt.Errorf("1Password item %q is missing public_key or secret_key fields", resolved.ItemTitle)
		}

		if opts.VerifyHash && !opts.Force {
			storedPublicHash := item.FieldValue("sha256_public")
			storedSecretHash := item.FieldValue("sha256_secret")
			if storedPublicHash == "" || storedSecretHash == "" {
				return fmt.Errorf("1Password item %q is missing hash fields; use --force to skip verification", resolved.ItemTitle)
			}

			actualPublicHash := sha256Hex([]byte(publicKey))
			actualSecretHash := sha256Hex([]byte(secretKey))
			if actualPublicHash != storedPublicHash {
				return fmt.Errorf("sha256 mismatch on public_key for %q (stored: %s, actual: %s)", resolved.ItemTitle, storedPublicHash, actualPublicHash)
			}
			if actualSecretHash != storedSecretHash {
				return fmt.Errorf("sha256 mismatch on secret_key for %q (stored: %s, actual: %s)", resolved.ItemTitle, storedSecretHash, actualSecretHash)
			}
		}

		if opts.DryRun {
			fmt.Printf("would restore %s -> GPG keyring\n", resolved.ItemTitle)
			continue
		}

		if opts.Force {
			if err := gpg.DeleteKey(resolved.Fingerprint); err != nil {
				return fmt.Errorf("failed to delete existing key %q: %w", resolved.Fingerprint, err)
			}
		}

		if err := gpg.ImportKey([]byte(publicKey)); err != nil {
			return fmt.Errorf("failed to import public_key for %q: %w", resolved.ItemTitle, err)
		}

		if err := gpg.ImportKey([]byte(secretKey)); err != nil {
			return fmt.Errorf("failed to import secret_key for %q: %w", resolved.ItemTitle, err)
		}

		fmt.Printf("restored %s -> GPG keyring\n", resolved.ItemTitle)
	}

	return nil
}
