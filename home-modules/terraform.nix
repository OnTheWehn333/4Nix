{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    opentofu
    terraform
    tflint
  ];
  home.sessionVariables = {
    CHECKPOINT_DISABLE = "1";
  };
}
