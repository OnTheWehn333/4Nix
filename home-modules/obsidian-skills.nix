{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Obsidian AI agent skills from kepano/obsidian-skills
    skills.kepano.obsidian-skills.obsidian-markdown
    skills.kepano.obsidian-skills.obsidian-bases
    skills.kepano.obsidian-skills.json-canvas
    skills.kepano.obsidian-skills.obsidian-cli
    skills.kepano.obsidian-skills.defuddle
  ];
}
