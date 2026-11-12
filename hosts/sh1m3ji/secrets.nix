{ lib, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/persist/var/lib/sops-nix/age/keys.txt";
    secrets =
      lib.genAttrs
        [
          "rin/github-pat"
          "rin/modelapi-key"
          "rin/anymodel-key"
          "rin/google-drive-token"
          "rin/google-drive-client-id"
          "rin/google-drive-client-secret"
          "rin/access-key-id"
          "rin/secret-access-key"
          "rin/endpoint"
          "rin/bucket"
          "rin/restic-password"
          "rin/ssh/company"
        ]
        (_: {
          owner = "rin";
          mode = "0400";
        })
      // {
        "rin/backup-paths" = {
          sopsFile = ../../secrets/backup.yaml;
          key = "paths";
          owner = "rin";
          mode = "0400";
        };
        "rin/backup-excludes" = {
          sopsFile = ../../secrets/backup.yaml;
          key = "excludes";
          owner = "rin";
          mode = "0400";
        };
        "rin/password".neededForUsers = true;
      };
  };
}
