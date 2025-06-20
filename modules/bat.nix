{ config, lib, pkgs, ... }:

{
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      style = "full";
    };
  };
}
