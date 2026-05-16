{
  config,
  lib,
  pkgs,
  ...
}: {
  xdg.configFile."k9s/config.yaml".text = ''
    k9s:
      ui:
        noIcons: true
  '';

  home.packages = with pkgs; [
    k9s
    kind
    kubectl
    kubelogin
    kubernetes-helm
  ];
}
