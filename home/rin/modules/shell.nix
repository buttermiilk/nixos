{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  githubPatPath = osConfig.sops.secrets."rin/github-pat".path;

  githubCredentialHelper = pkgs.writeShellApplication {
    name = "git-credential-github-sops";
    runtimeEnv.GITHUB_PAT_FILE = githubPatPath;
    text = builtins.readFile ../dotfiles/scripts/git-credential-github-sops.sh;
  };
in
{
  services.ssh-agent.enable = true;
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry-curses;
  };

  # Oh My Zsh comes from nixpkgs; Nix updates it with the rest of the system.
  programs.zsh = {
    enable = true;
    profileExtra = ''
      # Start the graphical session after logging in on the primary TTY. This
      # runs before .zshrc, so Zellij starts inside Kitty rather than around X11.
      if [[ -z "$DISPLAY" && "''${XDG_VTNR:-0}" == 1 ]]; then
        exec startx
      fi
    '';
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
      ll = "ls -l";
      "cd.." = "cd ..";
      stab = "shutdown now";
    };
    oh-my-zsh = {
      enable = true;
      theme = ""; # Powerlevel10k is loaded through programs.zsh.plugins.
      plugins = [
        "git"
        "sudo"
        "extract"
        "colored-man-pages"
        "z"
      ];
      extraConfig = ''
        ENABLE_CORRECTION="true"
        COMPLETION_WAITING_DOTS="true"
      '';
    };
    initContent = lib.mkMerge [
      # Load the packaged preset before the theme, which is sourced at order 900.
      (lib.mkOrder 890 ''
        if [[ -r "$HOME/.p10k.zsh" ]]; then
          source "$HOME/.p10k.zsh"
        else
          source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/config/p10k-classic.zsh
        fi
      '')
      (lib.mkOrder 1000 ''
        clear
        echo "Hey there!"
        echo "I'm Yomikawa in a terminal. Work your heart out!"
        echo ""
      '')
    ];
  };

  programs.git = {
    enable = true;

    ignores = [
      # Editor and OS artifacts
      "*~"
      "*.swp"
      "*.swo"
      ".DS_Store"

      # Nix and direnv artifacts
      ".direnv/"
      "result"
      "result-*"

      # Local model-assisted context
      "AGENTS.md"
      ".agents/"
      "CLAUDE.md"
      ".claude/"
      ".codex/"
    ];

    settings = {
      user = {
        name = "miilk";
        email = "53138512+buttermiilk@users.noreply.github.com";
        signingKey = "6EEA8F49B00E0EEA3A3164DEA9B7F275D0F64688";
      };

      commit.gpgSign = true;
      tag.gpgSign = true;
      gpg.format = "openpgp";

      init.defaultBranch = "main";

      credential."https://github.com" = {
        username = "buttermiilk";
        helper = lib.getExe githubCredentialHelper;
      };
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."company" = {
      HostName = "82.38.134.105";
      User = "rin";
      Port = 22;
      IdentityFile = osConfig.sops.secrets."rin/ssh/company".path;
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };
  };

  programs.zellij = {
    enable = true;
    enableZshIntegration = true;
    attachExistingSession = true;
    exitShellOnExit = true;
    settings.env = {
      # Do not let graphics-aware applications select an outer-terminal protocol
      # that Zellij cannot render. Capability queries can select Sixel instead.
      TERM_PROGRAM = "zellij";
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "kitty";
  };
}
