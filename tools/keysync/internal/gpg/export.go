package gpg

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// KeyMeta contains key metadata parsed from gpg --with-colons output.
type KeyMeta struct {
	Fingerprint  string
	Algorithm    string
	Capabilities string
	UID          string
	Created      string
	Expires      string
}

// ExportPublicKey exports the ASCII-armored public key for the given fingerprint.
func ExportPublicKey(fingerprint string) ([]byte, error) {
	cmd := exec.Command("gpg", "--batch", "--yes", "--no-tty", "--armor", "--export", fingerprint)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("gpg --export failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}

	if stdout.Len() == 0 {
		return nil, fmt.Errorf("gpg --export returned empty output for %s", fingerprint)
	}

	return stdout.Bytes(), nil
}

// ExportSecretKey exports the ASCII-armored secret key for the given fingerprint.
func ExportSecretKey(fingerprint string) ([]byte, error) {
	cmd := exec.Command("gpg", "--batch", "--yes", "--no-tty", "--armor", "--export-secret-keys", fingerprint)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("gpg --export-secret-keys failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}

	if stdout.Len() == 0 {
		return nil, fmt.Errorf("gpg --export-secret-keys returned empty output for %s", fingerprint)
	}

	return stdout.Bytes(), nil
}

// ExportSecretSubkey exports the ASCII-armored secret subkey material for a key fingerprint.
func ExportSecretSubkey(fingerprint string) ([]byte, error) {
	locked := fingerprint
	if !strings.HasSuffix(locked, "!") {
		locked += "!"
	}

	cmd := exec.Command("gpg", "--batch", "--yes", "--no-tty", "--armor", "--export-secret-subkeys", locked)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("gpg --export-secret-subkeys failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}

	if stdout.Len() == 0 {
		return nil, fmt.Errorf("gpg --export-secret-subkeys returned empty output for %s", locked)
	}

	return stdout.Bytes(), nil
}

// ReadKeyMeta reads key metadata for a fingerprint using gpg --with-colons output.
func ReadKeyMeta(fingerprint string) (*KeyMeta, error) {
	cmd := exec.Command("gpg", "--batch", "--yes", "--no-tty", "--with-colons", "--fixed-list-mode", "--list-keys", fingerprint)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("gpg --list-keys failed: %s: %w", strings.TrimSpace(stderr.String()), err)
	}

	meta := &KeyMeta{}
	lines := strings.Split(strings.TrimSpace(stdout.String()), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}

		fields := strings.Split(line, ":")
		if len(fields) < 10 {
			continue
		}

		switch fields[0] {
		case "pub", "sub", "sec", "ssb":
			if meta.Algorithm == "" {
				meta.Algorithm = algoName(fields[3])
				meta.Created = fields[5]
				meta.Expires = fields[6]
				if len(fields) > 11 {
					meta.Capabilities = fields[11]
				}
			}
		case "uid":
			if meta.UID == "" {
				meta.UID = fields[9]
			}
		case "fpr":
			if meta.Fingerprint == "" && fields[9] == fingerprint {
				meta.Fingerprint = fields[9]
			}
		}
	}

	if meta.Fingerprint == "" {
		meta.Fingerprint = fingerprint
	}
	if meta.Expires == "" {
		meta.Expires = "never"
	}

	return meta, nil
}

func algoName(id string) string {
	switch id {
	case "1":
		return "rsa"
	case "16":
		return "elgamal"
	case "17":
		return "dsa"
	case "18":
		return "ecdh"
	case "19":
		return "ecdsa"
	case "22", "25":
		return "ed25519"
	default:
		return "algo-" + id
	}
}
