{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    withPython3 = true;
    defaultEditor = true;
  };
}
