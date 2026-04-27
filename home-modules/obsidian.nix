{
  config,
  lib,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;

  cfg = config.services.obsidian;

  # Vaults that have encryption passwords set (non-null values only).
  # These secrets are for one-time/manual sync setup; the running sync daemon uses
  # credentials stored by obsidian-headless after `ob sync-setup`.
  vaultPasswordsNonNull = lib.filterAttrs (_: p: p != null) cfg.vaultPasswords;

  passwordSecrets = lib.foldl (acc: vault: acc // {
    "${vaultPasswordsNonNull.${vault}}" = {
      sopsFile = cfg.sopsFile;
    };
  }) {} (builtins.attrNames vaultPasswordsNonNull);
in {
  options.services.obsidian = {
    enable = lib.mkEnableOption "Obsidian vault(s)";

    syncMode = lib.mkOption {
      type = lib.types.enum ["gui" "headless" "none"];
      default = if isDarwin then "gui" else "none";
      description = ''
        How to sync vaults on this host. All vaults share this mode.
        - `gui`: use the Obsidian desktop app; no headless services are created
        - `headless`: use obsidian-headless CLI daemon services
        - `none`: vault directories only, no sync services
      '';
    };

    baseDir = lib.mkOption {
      type = lib.types.str;
      default = "ObsidianVaults";
      description = "Parent directory under $HOME containing vault folders.";
    };

    vaults = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of vault folder names to manage under baseDir.";
    };

    vaultPasswords = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = ''
        Per-vault encryption passwords (SOPS secret names, not the actual values).
        Set a vault's password to null (or omit the key) for unencrypted vaults.
        Example: { "4Vault" = "obsidian-4vault-password"; "WorkVault" = null; }
      '';
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/shared/secrets.yaml;
      description = "Path to the SOPS secrets file for vault passwords.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings =
      lib.optionals (cfg.syncMode == "gui" && isLinux) [
        "Obsidian GUI mode requires Darwin (macOS). Use syncMode = \"headless\" on Linux."
      ]
      ++ lib.optionals (cfg.syncMode == "headless" && isDarwin) [
        "Obsidian headless mode is for Linux only. On Darwin, use syncMode = \"gui\"."
      ];

    home.activation.createObsidianVaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
      for vault in ${lib.concatMapStringsSep " " lib.escapeShellArg cfg.vaults}; do
        vault_path="${cfg.baseDir}/$vault"
        if [ ! -d "$HOME/$vault_path" ]; then
          echo "[obsidian] Creating vault directory $HOME/$vault_path"
          mkdir -p "$HOME/$vault_path"
        fi
      done
    '';

    home.packages = with pkgs; lib.optionals isDarwin [obsidian]
      ++ lib.optionals (isLinux && cfg.syncMode == "headless") [nodejs_22];

    home.activation.checkObsidianHeadlessAvailable = lib.hm.dag.entryAfter ["createObsidianVaults"] ''
      if [ "${lib.boolToString (cfg.syncMode == "headless" && isLinux)}" = "true" ]; then
        if ! command -v ob &>/dev/null && [ ! -x "${config.node.npmGlobalPrefix}/bin/ob" ]; then
          echo "WARNING: 'ob' command not found."
          echo "         Obsidian headless sync requires the obsidian-headless npm package."
          echo "         Install with: npm install -g obsidian-headless"
          echo "         It should be installed to: ${config.node.npmGlobalPrefix}/bin"
        fi
      fi
    '';

    # SOPS secret entries for encrypted vault setup.
    sops.secrets = passwordSecrets;
  };
}
