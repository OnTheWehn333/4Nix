# home-modules/ranger.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Simply install ranger when this module is imported
  home.packages = with pkgs; [ranger];

  # Configure ranger with vim as default editor and image previews
  home.file.".config/ranger/rc.conf".text = ''
    # Image preview settings
    set preview_images true
    set open_all_images true
    set preview_images_method w3m

    # Git integration
    set vcs_aware true
    set vcs_backend_git enabled

    # Quality of life improvements
    set show_hidden true
    set confirm_on_delete multiple
    set automatically_count_files true
    set wrap_scroll true
  '';
}
