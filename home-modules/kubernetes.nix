{lib, pkgs, ...}: {
  xdg.configFile."k9s/config.yaml".text = ''
    k9s:
      ui:
        noIcons: true
  '';

  home.packages = with pkgs; [
    k9s
    kind
    minikube
    kubectl
    kubelogin
    kubernetes-helm
    tanka
    jsonnet
    jsonnet-bundler
    kustomize
    helmfile
    kubeconform
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    nerdctl
  ];
}
