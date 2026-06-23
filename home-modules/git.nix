{config, ...}: {
  home.file.".config/git/ignore".text = ''
    .DS_Store
    .sisyphus/
    .opencode/
    AGENTS.md
  '';

  programs.git = {
    enable = true;
    signing.signByDefault = true;
    settings.core.excludesFile = "${config.xdg.configHome}/git/ignore";
    settings.user = {
      name = "noahbalboa66";
      email = "noahwehn@gmail.com";
      init.defaultBranch = "master";
    };
    settings.pull.rebase = true;
    settings.rebase.autoStash = true;
  };
}
