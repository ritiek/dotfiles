{ pkgs, config, ... }:
{
  home.file.allowed_signers = {
    source =  ../chezmoi/dot_ssh/allowed_signers;
    target = "${config.home.homeDirectory}/.ssh/allowed_signers";
  };
  programs.git = {
    enable = true;
    userName = "Ritiek Malhotra";
    userEmail = "ritiekmalhotra123@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "nvim";
      commit.gpgsign = true;
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      gpg.ssh.defaultKeyCommand = "sh -c 'echo key::$(ssh-add -L)'";
      gpg.format = "ssh";
      # user.signingkey = "~/.ssh/id_ed25519.pub";
      # commit.verbose = true;
    };
    delta = {
      enable = true;
      options = {
        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-style = "bold yellow ul";
          file-decoration-style = "none";
        };
        features = "line-numbers decorations";
        whitespace-error-style = "22 reverse";
        plus-color = "#012800";
        minus-color = "#340001";
        syntax-theme = "Monokai Extended";
        # diff-so-fancy = true;
      };
    };
  };
}
