{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  awsR2 = pkgs.writeShellApplication {
    name = "aws-r2";
    runtimeInputs = [
      pkgs.awscli2
      pkgs.coreutils
    ];
    runtimeEnv = {
      SH1M3JI_R2_ACCESS_KEY_ID = osConfig.sops.secrets."rin/access-key-id".path;
      SH1M3JI_R2_SECRET_ACCESS_KEY = osConfig.sops.secrets."rin/secret-access-key".path;
      SH1M3JI_R2_ENDPOINT = osConfig.sops.secrets."rin/endpoint".path;
    };
    text = builtins.readFile ./awscli/aws-r2.sh;
  };
in
{
  programs.awscli = {
    enable = true;
    package = pkgs.awscli2;
  };

  home.packages = [ awsR2 ];

  programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
    lib.mkAfter ''
      autoload -U +X bashcompinit && bashcompinit
      complete -C ${lib.getExe' pkgs.awscli2 "aws_completer"} aws-r2
    ''
  );
}
