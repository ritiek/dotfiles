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
    #   nvim-osc52
    # ];
  };

  # xdg.configFile = {
  #   nvim = {
  #     source =  "/etc/nixos/chezmoi/dot_config/nvim/";
  #   };
  # };

  home.file = {
    init = {
      source = ./nvim/init.lua;
      target = "${config.home.homeDirectory}/.config/nvim/init.lua";
    };
    lua = {
      source = ./nvim/lua;
      target = "${config.home.homeDirectory}/.config/nvim/lua";
    };
    stylua = {
      source = ./nvim/dot_stylua.toml;
      target = "${config.home.homeDirectory}/.config/nvim/.stylua.toml";
    };
    # So that the lock file stays writable.
    lazy-lock = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.nvim-lazy-lock.json";
      target = "${config.home.homeDirectory}/.config/nvim/lazy-lock.json";
    };
  };
}
