{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [ claude-code ];
}

