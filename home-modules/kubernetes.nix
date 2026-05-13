{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    k9s
    kind
    kubectl
    kubelogin
    kubernetes-helm
  ];
}
