package config

import (
	"fmt"
	"os"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// ConfigError represents a configuration or usage error.
type ConfigError struct {
	Msg string
}

// Error returns the configuration error message.
func (e *ConfigError) Error() string {
	return e.Msg
}

// Config is the top-level keysync configuration.
type Config struct {
	Version int              `yaml:"version"`
	Vault   string           `yaml:"vault"`
	Keys    map[string]*Key  `yaml:"keys"`
	Hosts   map[string]*Host `yaml:"hosts"`
}

// Key defines one named key that can be synced.
type Key struct {
	Title       string             `yaml:"title"`
	Fingerprint string             `yaml:"fingerprint"`
	Subkeys     map[string]*Subkey `yaml:"subkeys,omitempty"`
}

// Subkey defines a named subkey under a top-level key.
type Subkey struct {
	Fingerprint string `yaml:"fingerprint"`
}

// Host defines key references for a specific machine.
type Host struct {
	Keys []string `yaml:"keys"`
}

// ResolvedRef is the result of resolving a dot-notation reference.
type ResolvedRef struct {
	KeyName     string
	SubkeyName  string
	Fingerprint string
	ParentFP    string
	ItemTitle   string
}

// Load reads and validates a keysync configuration file.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, &ConfigError{Msg: fmt.Sprintf("cannot read config file: %v", err)}
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, &ConfigError{Msg: fmt.Sprintf("invalid YAML: %v", err)}
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return &cfg, nil
}

// Validate checks the configuration for required fields and valid references.
func (c *Config) Validate() error {
	if c.Version != 1 {
		return &ConfigError{Msg: fmt.Sprintf("unsupported config version: %d (expected 1)", c.Version)}
	}

	if strings.TrimSpace(c.Vault) == "" {
		return &ConfigError{Msg: "vault is required"}
	}

	if len(c.Keys) == 0 {
		return &ConfigError{Msg: "keys must not be empty"}
	}

	for name, key := range c.Keys {
		if key == nil {
			return &ConfigError{Msg: fmt.Sprintf("keys.%s is null", name)}
		}
		if strings.TrimSpace(key.Title) == "" {
			return &ConfigError{Msg: fmt.Sprintf("keys.%s.title is required", name)}
		}
		keyFP := strings.TrimSpace(key.Fingerprint)
		if keyFP == "" {
			return &ConfigError{Msg: fmt.Sprintf("keys.%s.fingerprint is required", name)}
		}
		if len(keyFP) != 40 {
			return &ConfigError{Msg: fmt.Sprintf("keys.%s.fingerprint must be 40 characters", name)}
		}
		if len(key.Subkeys) == 0 {
			return &ConfigError{Msg: fmt.Sprintf("keys.%s.subkeys must not be empty", name)}
		}
		for subName, sub := range key.Subkeys {
			if sub == nil {
				return &ConfigError{Msg: fmt.Sprintf("keys.%s.subkeys.%s is null", name, subName)}
			}
			subFP := strings.TrimSpace(sub.Fingerprint)
			if subFP == "" {
				return &ConfigError{Msg: fmt.Sprintf("keys.%s.subkeys.%s.fingerprint is required", name, subName)}
			}
			if len(subFP) != 40 {
				return &ConfigError{Msg: fmt.Sprintf("keys.%s.subkeys.%s.fingerprint must be 40 characters", name, subName)}
			}
		}
	}

	if len(c.Hosts) == 0 {
		return &ConfigError{Msg: "hosts must not be empty"}
	}

	for hostName, host := range c.Hosts {
		if host == nil {
			return &ConfigError{Msg: fmt.Sprintf("hosts.%s is null", hostName)}
		}
		if len(host.Keys) == 0 {
			return &ConfigError{Msg: fmt.Sprintf("hosts.%s.keys must not be empty", hostName)}
		}
		for i, keyRef := range host.Keys {
			if !strings.Contains(keyRef, ".") {
				return &ConfigError{Msg: fmt.Sprintf("hosts.%s.keys[%d] must be dot notation key.subkey: %q", hostName, i, keyRef)}
			}
			if _, err := c.ResolveRef(keyRef); err != nil {
				return &ConfigError{Msg: fmt.Sprintf("hosts.%s.keys[%d] has invalid reference %q: %v", hostName, i, keyRef, err)}
			}
		}
	}

	return nil
}

// ResolveRef resolves a key.subkey reference to key metadata.
func (c *Config) ResolveRef(ref string) (*ResolvedRef, error) {
	parts := strings.Split(ref, ".")
	if len(parts) != 2 || strings.TrimSpace(parts[0]) == "" || strings.TrimSpace(parts[1]) == "" {
		return nil, &ConfigError{Msg: fmt.Sprintf("invalid key reference %q (expected key.subkey)", ref)}
	}

	keyName := parts[0]
	subkeyName := parts[1]

	key, err := c.GetKey(keyName)
	if err != nil {
		return nil, err
	}

	sub, ok := key.Subkeys[subkeyName]
	if !ok || sub == nil {
		return nil, &ConfigError{Msg: fmt.Sprintf("subkey %q not found under key %q", subkeyName, keyName)}
	}

	return &ResolvedRef{
		KeyName:     keyName,
		SubkeyName:  subkeyName,
		Fingerprint: sub.Fingerprint,
		ParentFP:    key.Fingerprint,
		ItemTitle:   key.Title + "/" + subkeyName,
	}, nil
}

// GetKey returns a key by name.
func (c *Config) GetKey(name string) (*Key, error) {
	key, ok := c.Keys[name]
	if !ok {
		return nil, &ConfigError{Msg: fmt.Sprintf("key %q not found", name)}
	}
	return key, nil
}

// GetHost returns a host by name.
func (c *Config) GetHost(name string) (*Host, error) {
	host, ok := c.Hosts[name]
	if !ok {
		return nil, &ConfigError{Msg: fmt.Sprintf("host %q not found", name)}
	}
	return host, nil
}

// AllKeyNames returns all configured key names in sorted order.
func (c *Config) AllKeyNames() []string {
	names := make([]string, 0, len(c.Keys))
	for name := range c.Keys {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
