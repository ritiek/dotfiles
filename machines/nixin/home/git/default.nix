{ pkgs, config, lib, ... }:
{
  home.file.allowed_signers = {
    source =  ./allowed_signers;
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
      tag.gpgsign = true;

      gpg.format = lib.mkIf (!config.services.gpg-agent.enable) "ssh";
      # https://keys.openpgp.org/vks/v1/by-fingerprint/66FF60997B04845FF4C0CB4FEB6FC9F9FC964257
      # $ gpg --recv-keys 66FF60997B04845FF4C0CB4FEB6FC9F9FC964257
      user.signingkey = lib.mkIf config.services.gpg-agent.enable "ECAA33C16AE3563A";

      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      gpg.ssh.defaultKeyCommand = "sh -c 'echo key::$(ssh-add -L)'";
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
