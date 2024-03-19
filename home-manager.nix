{ config, pkgs, lib, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/refs/heads/release-23.11.zip";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.ritiek = {
    /* The home.stateVersion option does not have a default and must be set */
    home = {
      stateVersion = "23.11";
      packages = with pkgs; [
        wezterm
      ];
    };
    /* Here goes the rest of your home-manager config, e.g. home.packages = [ pkgs.foo ]; */
    gtk = {
      enable = true;
      cursorTheme = {
        name = "Qogir";
	package = pkgs.qogir-icon-theme;
        size = 24;
      };
      font = {
        name = "Cantarell";
        package = pkgs.cantarell-fonts;
	size = 11;
      };
      iconTheme = {
        name = "Dracula";
        package = pkgs.dracula-icon-theme;
      };
      # theme = {
      #   name = "Catppucin-Mocha-Standard-Red-Dark";
      #   package = pkgs.catppuccin-gtk.override {
      #     # accents = [ "lavender" ];
      #     accents = [ "red-dark" ];
      #     size = "standard";
      #     variant = "mocha";
      #   };
      # };
      theme = {
        name = "Dracula";
        package = pkgs.dracula-theme;
      };
      gtk3.extraConfig = {
        gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
        gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
        gtk-button-images = 0;
        gtk-menu-images = 0;
        gtk-enable-event-sounds = 1;
        gtk-enable-input-feedback-sounds = 0;
        gtk-xft-antialias = 1;
        gtk-xft-hinting = 1;
        gtk-xft-hintstyle = "hintslight";
        gtk-xft-rgba = "rgb";
        gtk-application-prefer-dark-theme = 1;
      };
    };
    programs.command-not-found.enable = true;
    programs.btop = {
      enable = true;
      settings = {
        color_theme = "adapta";
	vim_keys = true;
	cpu_graph_lower = "iowait";
      };
    };
    programs.git = {
      enable = true;
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
    programs.wezterm = {
      enable = true;
      extraConfig = ''
-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

wezterm.on('toggle-colorscheme', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.color_scheme then
    overrides.color_scheme = 'Dracula'
  else
    overrides.color_scheme = nil
  end
  window:set_config_overrides(overrides)
end)

-- This is where you actually apply your config choices

config.enable_wayland = true
-- config.color_scheme = 'Dracula'
config.color_scheme = 'Tartan (terminal.sexy)'
config.hide_tab_bar_if_only_one_tab = true
config.font = wezterm.font(
  "FantasqueSansM Nerd Font Mono", {
    stretch = 'Expanded',
    weight = 'Regular'
  }
)
config.font_size = 12.2
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.initial_rows = 30
config.initial_cols = 90
config.keys = {
  -- Disable the default Alt+Enter fullscreen behaviour as
  -- this is used by Neovim GitHub Copilot to synthesize
  -- solutions.
  {
    key = 'Enter',
    mods = 'ALT',
    action = wezterm.action.DisableDefaultAssignment,
  },
  {
    key = 'E',
    mods = 'CTRL',
    action = wezterm.action.EmitEvent 'toggle-colorscheme',
  },
}
-- Maybe I should try fix this instead of suppressing this warning.
config.warn_about_missing_glyphs = false


-- config.window_background_image = "/home/ritiek/Pictures/island-fantastic-coast-mountains-art.jpg"
-- config.window_background_opacity = 0.7

-- and finally, return the configuration to wezterm
return config
      '';
    };
    programs.zsh = {
      enable = true;
      profileExtra = ''
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

export EDITOR="nvim"
export VIM="$HOME/.config/nvim"
export VIMRUNTIME="/usr/share/nvim/runtime"
export BROWSER="google-chrome-stable"
export LESS="--mouse --wheel-lines=3 -r"
export LESSOPEN="|$HOME/.lessfilter %s"
# Reduce lag when switching between Normal and Insert mode with Vi
# bindings in zsh
export KEYTIMEOUT=1

export OPENCV_LOG_LEVEL=ERROR

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# export JAVA_OPTS="-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee"
export GOPATH="$HOME/go"

export POWERLINE_BASH_CONTINUATION=1
export POWERLINE_BASH_SELECT=1

export ESPIDF=/opt/esp-idf

# export QT_QPA_PLATFORMTHEME="qt5ct"

# export PYENV_ROOT="$HOME/.pyenv"
# command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"

# set PATH so it includes user's private bin directories
PATH="$HOME/bin:$HOME/.local/bin:$PATH"
PATH="$HOME/go/bin:$PATH"
PATH="$HOME/.cabal/bin:$PATH"
PATH="$HOME/.rbenv/bin:$PATH"
PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
PATH="$HOME/.rbenv/bin:$PATH"
PATH="$HOME/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$HOME/bin/gyb:$PATH"
PATH="$HOME/.cargo/bin:$PATH"
PATH="$HOME/Android/flutter/bin:$PATH"
PATH="$HOME/.gem/ruby/2.5.0/bin:$PATH"
PATH="/snap/bin:$PATH"
export PATH

alias cp="cp --reflink=auto --sparse=always"

eval $(keychain --eval --quiet --noask)
      '';
      initExtraFirst = ''
source ~/.zprofile

# Space prefix to suppress history
setopt HIST_IGNORE_SPACE

# Refresh commands-cache for tab-completion
zstyle ":completion:*:commands" rehash 1

# Set your own notification threshold
bgnotify_threshold=5

function bgnotify_formatted {
  ## $1=exit_status, $2=command, $3=elapsed_time
  [ $1 -eq 0 ] && title="Succeeded" || title="Failed"
  bgnotify "$title in $3s" "$2";
}
      '';
      initExtraBeforeCompInit = ''
# Allow symlinks
ZSH_DISABLE_COMPFIX=true
      '';
      initExtra = ''
# ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=59'

# Make Enter key on the numpad work as Return key
bindkey '^[OM' accept-line

# Reverse search like in Bash
bindkey '^R' history-incremental-search-backward

bindkey '^[[Z' reverse-menu-complete
# Navigate to previous selection with shift+tab
# when using tab completition for navigation

# zsh-autosuggetsions maps
## map autosuggest-accept to ctrl+/
bindkey '^_' autosuggest-accept
#bindkey '^M' autosuggest-execute

# Enable Vi bindings
bindkey -v

autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd ' ' edit-command-line
bindkey "^?" backward-delete-char
      '';
      envExtra = ''
      '';
      shellAliases = {
        ll = "ls -l";
        update = "sudo nixos-rebuild switch";
	# Check if xclip is even being used in hyprland
	xclip = "xclip -selection clipboard";
      };
      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
	  # File path is $src + $file
          src = ./.;
          file = "p10k.zsh";
        }
      ];
      enableAutosuggestions = true;
      enableCompletion = true;
      enableVteIntegration = true;
      history = {
        save = 10000;
	size = 10000;
	expireDuplicatesFirst = true;
	extended = true;
      };
      oh-my-zsh = {
        enable = true;
	plugins = [
	  "bgnotify"
	  "colored-man-pages"
	  "command-not-found"
	];
      };
      syntaxHighlighting = {
        enable = true;
	styles = {
	  path = "fg=cyan";
	  path_prefix = "fg=magenta";
	};
	highlighters = [
	  "main"
	  "brackets"
	];
      };
    };
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
