{ config, ... }:
{
  # XXX: Workaround to SSH when using Ghostty.
  # https://ghostty.org/docs/help/terminfo#configure-ssh-to-fall-back-to-a-known-terminfo-entry
  programs.ssh = {
    extraConfig = ''
      Host *
        SetEnv TERM=xterm-256color
    '';
  };
}
