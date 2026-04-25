{
  config,
  lib,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;

  cfg = config.services.obsidian;

  # Per-vault full path under baseDir
  vaultPath = vaultName: "${config.home.homeDirectory}/${cfg.baseDir}/${vaultName}";

  # Systemd service name for a vault
  serviceName = vaultName: "obsidian-${vaultName}";

  # Vaults that have encryption passwords set (non-null values only)
  vaultPasswordsNonNull = lib.filterAttrs (_: p: p != null) cfg.vaultPasswords;

  # ---------- Per-vault systemd service builder ----------
  mkVaultService = vaultName: password:
    let
      envBlock = if password != null
        then { Environment = [ "VAULT_PASSWORD=${config.sops.secrets."${password}".path}" ]; }
        else {};
    in {
      Unit = {
        Description = "Obsidian Headless Sync (${vaultName})";
        After = [ "home.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.nodejs_22}/bin/ob sync --continuous --vault ${vaultPath vaultName}";
        Restart = "on-failure";
        RestartSec = "5s";
      } // envBlock;
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

  # ---------- SOPS secret entries for encrypted vaults ----------
  passwordSecrets = lib.foldl (acc: vault: acc // {
    "${vaultPasswordsNonNull.${vault}}" = {
      sopsFile = cfg.sopsFile;
    };
  }) {} (builtins.attrNames vaultPasswordsNonNull);

  # ---------- Systemd services for all headless vaults ----------
  encryptedServices = lib.foldl (acc: vault: acc // {
    "${serviceName vault}" = mkVaultService vault vaultPasswordsNonNull.${vault};
  }) {} (builtins.attrNames vaultPasswordsNonNull);

  unencryptedVaultNames = lib.filter (v: !(lib.hasAttr v vaultPasswordsNonNull)) cfg.vaults;
  unencryptedServices = lib.foldl (acc: vaultName: acc // {
    "${serviceName vaultName}" = mkVaultService vaultName null;
  }) {} unencryptedVaultNames;

  allVaultServices = encryptedServices // unencryptedServices;

in {
  options.services.obsidian = {
    enable = lib.mkEnableOption "Obsidian vault(s)";

    syncMode = lib.mkOption {
      type = lib.types.enum [ "gui" "headless" "none" ];
      default = if isDarwin then "gui" else "none";
      description = ''
        How to sync vaults on this host. All vaults share this mode.
        - `gui`: use Obsidian desktop app (Darwin only)
        - `headless`: use obsidian-headless CLI daemon (Linux only)
        - `none`: vault directories only, no sync
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
    # ---------- Validation ----------
    warnings =
      lib.optionals (cfg.syncMode == "gui" && isLinux) [
        "Obsidian GUI mode requires Darwin (macOS). Use syncMode = \"headless\" on Linux."
      ]
      ++ lib.optionals (cfg.syncMode == "headless" && isDarwin) [
        "Obsidian headless mode is for Linux only. On Darwin, use syncMode = \"gui\"."
      ];

    # ---------- Vault directories ----------
    home.activation.createObsidianVaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for vault in ${lib.concatMapStringsSep " " lib.escapeShellArg cfg.vaults}; do
        vault_path="${cfg.baseDir}/$vault"
        if [ ! -d "$HOME/$vault_path" ]; then
          echo "[obsidian] Creating vault directory $HOME/$vault_path"
          mkdir -p "$HOME/$vault_path"
        fi
      done
    '';

    # ---------- Packages ----------
    home.packages = with pkgs; lib.optionals isDarwin [ obsidian ]
      ++ lib.optionals (isLinux && cfg.syncMode == "headless") [ nodejs_22 ];

    # ---------- obsidian-headless CLI installation (headless mode, Linux) ----------
    home.activation.installObsidianHeadless = lib.hm.dag.entryAfter [ "createObsidianVaults" ] ''
      if [ "${lib.boolToString (cfg.syncMode == "headless" && isLinux)}" = "true" ]; then
        if ! command -v ob &>/dev/null; then
          echo "[obsidian] Installing obsidian-headless CLI..."
          ${lib.getExe pkgs.nodejs_22}/bin/npm install -g obsidian-headless 2>&1 || true
        fi
      fi
    '';

    # ---------- SOPS secrets for encrypted vaults ----------
    sops.secrets = passwordSecrets;

    # ---------- Systemd user services (headless mode only) ----------
    systemd.user.services = lib.optionalAttrs (cfg.syncMode == "headless" && isLinux) allVaultServices;
  };
}
