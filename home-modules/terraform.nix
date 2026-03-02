{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [
    terraform
    tflint
  ];
  home.sessionVariables = {
    CHECKPOINT_DISABLE = "1";
  };
}
