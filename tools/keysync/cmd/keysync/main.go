package main

import (
	"errors"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/OnTheWehn333/keysync/internal/config"
	"github.com/OnTheWehn333/keysync/internal/engine"
)

var (
	cfgFile string
)

var rootCmd = &cobra.Command{
	Use:   "keysync",
	Short: "Sync and restore named GPG keys with 1Password",
}

var syncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Sync host subkey references to 1Password",
	RunE: func(cmd *cobra.Command, args []string) error {
		hostName, _ := cmd.Flags().GetString("host")
		syncAll, _ := cmd.Flags().GetBool("all")
		if (hostName == "" && !syncAll) || (hostName != "" && syncAll) {
			return &config.ConfigError{Msg: "exactly one of --host or --all is required"}
		}

		cfg, err := config.Load(cfgFile)
		if err != nil {
			return err
		}

		if syncAll {
			return engine.SyncAll(cfg)
		}

		return engine.SyncHost(cfg, hostName)
	},
}

var restoreCmd = &cobra.Command{
	Use:   "restore",
	Short: "Restore all host keys from 1Password",
	RunE: func(cmd *cobra.Command, args []string) error {
		hostName, _ := cmd.Flags().GetString("host")
		if hostName == "" {
			return &config.ConfigError{Msg: "--host is required"}
		}

		cfg, err := config.Load(cfgFile)
		if err != nil {
			return err
		}

		dryRun, _ := cmd.Flags().GetBool("dry-run")
		force, _ := cmd.Flags().GetBool("force")
		verifyHash, _ := cmd.Flags().GetBool("verify-hash")

		return engine.Restore(cfg, hostName, engine.RestoreOpts{
			DryRun:     dryRun,
			Force:      force,
			VerifyHash: verifyHash,
		})
	},
}

var backupCmd = &cobra.Command{
	Use:   "backup",
	Short: "Backup top-level keys to 1Password",
	RunE: func(cmd *cobra.Command, args []string) error {
		keyName, _ := cmd.Flags().GetString("key")
		backupAll, _ := cmd.Flags().GetBool("all")
		if (keyName == "" && !backupAll) || (keyName != "" && backupAll) {
			return &config.ConfigError{Msg: "exactly one of --key or --all is required"}
		}

		cfg, err := config.Load(cfgFile)
		if err != nil {
			return err
		}

		if backupAll {
			return engine.BackupAll(cfg)
		}

		return engine.BackupKey(cfg, keyName)
	},
}

var backupRestoreCmd = &cobra.Command{
	Use:   "restore",
	Short: "Restore a top-level key backup from 1Password",
	RunE: func(cmd *cobra.Command, args []string) error {
		keyName, _ := cmd.Flags().GetString("key")
		if keyName == "" {
			return &config.ConfigError{Msg: "--key is required"}
		}

		cfg, err := config.Load(cfgFile)
		if err != nil {
			return err
		}

		dryRun, _ := cmd.Flags().GetBool("dry-run")
		force, _ := cmd.Flags().GetBool("force")
		verifyHash, _ := cmd.Flags().GetBool("verify-hash")

		return engine.BackupRestore(cfg, keyName, engine.RestoreOpts{
			DryRun:     dryRun,
			Force:      force,
			VerifyHash: verifyHash,
		})
	},
}

func init() {
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "keysync.yaml", "path to keysync config file")

	syncCmd.Flags().String("host", "", "host name from keysync config")
	syncCmd.Flags().Bool("all", false, "sync all unique host key references")

	restoreCmd.Flags().String("host", "", "host name from keysync config")
	_ = restoreCmd.MarkFlagRequired("host")

	restoreCmd.Flags().Bool("dry-run", false, "print what would be imported without importing")
	restoreCmd.Flags().Bool("force", false, "delete and reimport keys")
	restoreCmd.Flags().Bool("verify-hash", true, "verify sha256 hashes before importing")

	backupCmd.Flags().String("key", "", "top-level key name from keysync config")
	backupCmd.Flags().Bool("all", false, "backup all top-level keys")

	backupRestoreCmd.Flags().String("key", "", "top-level key name from keysync config")
	_ = backupRestoreCmd.MarkFlagRequired("key")
	backupRestoreCmd.Flags().Bool("dry-run", false, "print what would be imported without importing")
	backupRestoreCmd.Flags().Bool("force", false, "delete and reimport keys")
	backupRestoreCmd.Flags().Bool("verify-hash", true, "verify sha256 hashes before importing")

	backupCmd.AddCommand(backupRestoreCmd)

	rootCmd.AddCommand(syncCmd)
	rootCmd.AddCommand(restoreCmd)
	rootCmd.AddCommand(backupCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		var cfgErr *config.ConfigError
		if errors.As(err, &cfgErr) {
			fmt.Fprintln(os.Stderr, cfgErr.Error())
			os.Exit(2)
		}
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
