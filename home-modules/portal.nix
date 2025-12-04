{ pkgs, ... }:

{
  home.packages = with pkgs; [ portal ];
}
