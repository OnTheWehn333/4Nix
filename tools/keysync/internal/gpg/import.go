package gpg

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// ImportKey imports an ASCII-armored key (public or secret) into the GPG keyring.
// The key material is passed via stdin to avoid writing to disk.
func ImportKey(armoredKey []byte) error {
	cmd := exec.Command("gpg",
		"--batch", "--yes", "--no-tty",
		"--import",
	)

	cmd.Stdin = bytes.NewReader(armoredKey)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gpg --import failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}

	return nil
}

// DeleteKey deletes secret and public key material for the given fingerprint.
func DeleteKey(fingerprint string) error {
	cmd := exec.Command("gpg", "--batch", "--yes", "--no-tty", "--delete-secret-and-public-key", fingerprint)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		errMsg := strings.ToLower(strings.TrimSpace(stderr.String()))
		if strings.Contains(errMsg, "not found") {
			return nil
		}
		return fmt.Errorf("gpg --delete-secret-and-public-key failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}

	return nil
}
