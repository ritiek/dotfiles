{ pkgs, config, lib, ... }:
{
  programs.zsh = {
    enable = true;
    profileExtra = ''
export WAYLAND_DISPLAY=wayland-1
# eval $(keychain --eval --quiet --noask)
    '';
    initContent = ''
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "$HOME/.cache/p10k-instant-prompt-$USER.zsh" ]]; then
  source "$HOME/.cache/p10k-instant-prompt-$USER.zsh"
fi

source $HOME/.p10k.zsh
source $HOME/.zprofile

# Space prefix to suppress history
setopt HIST_IGNORE_SPACE

# Refresh commands-cache for tab-completion
zstyle ":completion:*:commands" rehash 1

# Set your own notification threshold
bgnotify_threshold=7

function bgnotify_formatted {
  ## $1=exit_status, $2=command, $3=elapsed_time
  [ $1 -eq 0 ] && title="Succeeded" || title="Failed"
  bgnotify "$title in $3s" "$2";
}

# Allow symlinks
ZSH_DISABLE_COMPFIX=true

# ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=59'

# Make Enter key on the numpad work as Return key
bindkey '^[OM' accept-line

bindkey '^[[Z' reverse-menu-complete
# Navigate to previous selection with shift+tab
# when using tab completition for navigation

# Enable Vi bindings
bindkey -v

# zsh-autosuggetsions maps
## map autosuggest-accept to ctrl+/
bindkey '^_' autosuggest-accept
bindkey '^K' autosuggest-execute

# Reverse search like in Bash
# bindkey '^R' history-incremental-search-backward
# bindkey '^S' history-incremental-search-forward
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^S' history-incremental-pattern-search-forward

autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd ' ' edit-command-line
bindkey "^?" backward-delete-char

${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
      '';
      envExtra = ''
# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# export EDITOR="nvim"
# This messes up Neovim config on NixOS, so commenting it out:
# export VIM="$HOME/.config/nvim"
# export VIMRUNTIME="/usr/share/nvim/runtime"

# Required by Opencode.
export COLORTERM=truecolor

export BROWSER="zen-beta"
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

# export POWERLINE_BASH_CONTINUATION=1
# export POWERLINE_BASH_SELECT=1

export ESPIDF=/opt/esp-idf

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
    '';
    shellAliases = {
      # Check if xclip is even being used in hyprland
      # xclip = "xclip -selection clipboard";
      cp = "cp --reflink=auto --sparse=always";
      a = "shpool attach";

      sops-ssh = "SOPS_AGE_KEY_CMD='ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key' sops";
      sops-ssh-home = "SOPS_AGE_KEY_CMD='ssh-to-age -private-key -i /home/${config.home.username}/.ssh/sops.id_ed25519' sops";
      sops-fido2-hmac = "SOPS_AGE_KEY_CMD='age-plugin-fido2-hmac -m' sops";

      # Eval these in your shell manually, e.g: eval $(ssh-auth-sock)
      ssh-auth-sock = "echo export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent";
      gpg-auth-sock = "echo export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)";
      "discordchatexporter-cli@env" = "discordchatexporter-cli export --media --reuse-media --markdown false --format Json --output . --channel";
    };
    localVariables = {
      SSH_AUTH_SOCK = (
        if config.services.gpg-agent.enableSshSupport then
          "$(gpgconf --list-dirs agent-ssh-socket)"
        else
          "$SSH_AUTH_SOCK"
      );
    };
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      # XXX: Commenting this out as it looks to have problems with
      # using p10k-config.zsh through symlink. So, using `home.file`
      # to setup the config later in this file.
      # {
      #   name = "powerlevel10k-config";
      #   # File path is $src + $file
      #   # src = ../../../chezmoi;
      #   # file = "dot_p10k.zsh";
      #   # src = ./.;
      #   # file = "p10k-config.zsh";
      #
      #   # src = ./p10k-config;
      #   # file = "p10k-config.zsh";
      #
      #   src = ./p10k-config;
      #   file = "p10k-config.zsh";
      # }
    ];
    autosuggestion.enable = true;
    enableCompletion = true;
    enableVteIntegration = true;
    autocd = true;
    history = {
      save = 10000;
      size = 10000;
      expireDuplicatesFirst = true;
      extended = true;
    };
    # defaultKeymap = "emacs";
    oh-my-zsh = {
      enable = true;
      plugins = [
        # "git"
        "bgnotify"
        "colored-man-pages"
        "command-not-found"
        "tailscale"
	# Commenting out as it break Ctrl+C to clear command in some scenarios.
        # "history-substring-search"
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

  home.file = {
    p10k-config = {
      source = ./p10k-config/p10k-config.zsh;
      target = "${config.home.homeDirectory}/.p10k.zsh";
    };
  };
}
