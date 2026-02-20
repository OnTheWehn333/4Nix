{
  config,
  lib,
  pkgs,
  ...
}: let
  git = "${pkgs.git}/bin/git";
  repoUrl = "https://github.com/OnTheWehn333/nvim-config.git";
  targetDir = "${config.home.homeDirectory}/.config/nvim";
  branch = "master";
  isDarwin = pkgs.stdenv.isDarwin;
in {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    # Core plugins
    plugins = with pkgs.vimPlugins; [
      # Only include lazy-nvim since your config uses it to manage other plugins
      lazy-nvim
    ];
    extraPackages = with pkgs; (
      [
        # Base dependencies
        nodejs
        python3
        curl
        unzip
        ripgrep
        fd
        lazygit
        gh
        tmux
        go

        # LSPs & formatters (Nix-provided, bypass Mason on NixOS)
        alejandra
        lua-language-server
        nil
        rust-analyzer
        stylua
        gopls
        terraform-ls
        yamlfmt
        kulala-fmt
        netcoredbg

        # JVM tools
        jdk
        jdt-language-server
        ktlint
        kotlin-language-server
        google-java-format

        # .NET tools
        dotnet-sdk
        csharpier
        roslyn-ls
      ]
      ++ lib.optionals (!isDarwin) [gcc gnumake binutils glibc]
    );
  };

  home.activation.cloneOrUpdateNvimConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
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
