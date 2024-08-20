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
      wl-clipboard-rs
      stylua
      deno
      clang-tools
      lua-language-server
      python312
      python312Packages.python-lsp-server
      rust-analyzer
      typescript-language-server
      gcc
      cargo
      rustfmt
    ];

    # plugins = with pkgs.vimPlugins; [
    # ];
  };

  # xdg.configFile = {
  #   nvim = {
  #     source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/chezmoi/dot_config/nvim/";
  #   };
  # };
  home.file.nvim = {
    source = config.lib.file.mkOutOfStoreSymlink ../chezmoi/dot_config/nvim;
    target = "${config.home.homeDirectory}/.config/nvim";
  };
}
