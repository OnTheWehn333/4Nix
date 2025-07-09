{ config, lib, pkgs, ... }:

let
  git = "${pkgs.git}/bin/git";
  repoUrl = "https://github.com/OnTheWehn333/nvim-config.git";
  targetDir = "${config.home.homeDirectory}/.config/nvim";
  branch = "master";
in {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    # Core plugins
    plugins = with pkgs.vimPlugins;
      [
        # Only include lazy-nvim since your config uses it to manage other plugins
        lazy-nvim
      ];
    # Only include the base dependencies needed for Mason to work
    extraPackages = with pkgs; [
      # Essential for Mason
      nodejs
      curl
      unzip
      # Core search utilities used by plugins like telescope
      ripgrep
      fd
      # For lazygit integration
      lazygit
      gh
      # For tmux integration
      tmux
      # To build
      gcc
      gnumake
      glibc
      binutils
      go
    ];
  };

  home.activation.cloneOrUpdateNvimConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "${targetDir}" ]; then
        echo "[nvim] Creating ${targetDir} and cloning Neovim config"
        mkdir -p "${targetDir}"
        ${git} clone --branch ${branch} ${repoUrl} "${targetDir}"
      elif [ ! -d "${targetDir}/.git" ]; then
        echo "[nvim] ${targetDir} exists but is not a Git repo — skipping pull"
      else
        echo "[nvim] Checking for local changes in ${targetDir}"
        if ${git} -C "${targetDir}" diff --quiet && ${git} -C "${targetDir}" diff --cached --quiet; then
          echo "[nvim] Pulling latest from ${branch}"
          ${git} -C "${targetDir}" pull origin ${branch}
        else
          echo "[nvim] Local changes detected — skipping pull"
        fi
      fi
    '';
}
