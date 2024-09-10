{ pkgs, config, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;

    extraPackages = with pkgs; [
      xclip
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
  };

  home.file.nvim = {
    source =  ./nvim;
    target = "${config.home.homeDirectory}/.config/nvim";
  };
}
