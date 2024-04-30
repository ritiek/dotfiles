{ pkgs, config, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # colorschemes.gruvbox.enable = true;
    # plugins.lightline.enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;

    extraPackages = with pkgs; [
      xclip
      wl-clipboard
      lua-language-server
      stylua
    ];

    # plugins = with pkgs.vimPlugins; [
    # ];
  };

  # xdg.configFile = {
  #   "nvim" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/chezmoi/dot_config/nvim/";
  #   };
  # };

}
