{ config, lib, pkgs, ... }:

{
  programs.cava = {
    enable = true;
    settings = {
      general = {
        framerate = 60;
        autosens = 1;
      };
      color = {
        background = "black";
        foreground = "blue";
      };
    };
  };
}
