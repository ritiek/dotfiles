{ pkgs, config, lib, ... }:
{
  programs.zsh = {
    enable = true;
    profileExtra = ''
      export WAYLAND_DISPLAY=wayland-1
      # eval $(keychain --eval --quiet --noask)
    '';
    initContent = ''
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

        # This isn't needed if programs.fzf.enableZshIntegration is set to true.
        # if [ -n "$\{commands[fzf-share]}" ]; then
        #   source "$(fzf-share)/key-bindings.zsh"
        #   source "$(fzf-share)/completion.zsh"
        # fi

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
        bindkey '^K' autosuggest-accept
        bindkey '^_' autosuggest-execute

        # Reverse search like in Bash
        # bindkey '^R' history-incremental-search-backward
        # bindkey '^S' history-incremental-search-forward

        # Commented out to allow fzf's fuzzy Ctrl+R history search
        # bindkey '^R' history-incremental-pattern-search-backward
        # bindkey '^S' history-incremental-pattern-search-forward

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

        # FZF options: hide progress counter
        export FZF_DEFAULT_OPTS='--info=hidden --height=30%'
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

        if [ -n "$SSH_CONNECTION" ] && [ -z "$DISPLAY" ]; then
          export XAUTHORITY="$(ls "/run/user/$(id -u)/.mutter-Xwaylandauth*" 2>/dev/null | head -1)"
        fi

        export SOPS_AGE_KEY_CMD="${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i ${config.home.homeDirectory}/.ssh/sops.id_ed25519"

        # Make Tab use fzf fuzzy completion instead of needing **
        export FZF_COMPLETION_TRIGGER="**"
    '';
    shellAliases = {
      # Check if xclip is even being used in hyprland
      # xclip = "xclip -selection clipboard";
      cp = "cp --reflink=auto --sparse=always";
      a = "shpool attach";
      chafa = "chafa --format=kitty";
      mpv-kitty = "mpv --profile=sw-fast --vo=kitty --vo-kitty-use-shm=yes --really-quiet";
      scrcpy-opengl = "scrcpy --render-driver=opengl";

      # $ ffmpeg-intel-hw-accel -i Big_Buck_Bunny_1080_10s_5MB.mp4 -c:v hevc_qsv output_qsv.mp4
      # $ ffmpeg-intel-hw-accel -i Big_Buck_Bunny_1080_10s_5MB.mp4 -vf 'format=nv12,hwupload' -c:v h264_vaapi output_h264.mp4
      ffmpeg-intel-hw-accel = "LIBVA_DRIVER_NAME=iHD ffmpeg -hwaccel vaapi -vaapi_device /dev/dri/renderD128";

      sops-ssh = "SOPS_AGE_KEY_CMD='ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key' sops";
      sops-ssh-home = "SOPS_AGE_KEY_CMD='ssh-to-age -private-key -i ${config.home.homeDirectory}/.ssh/sops.id_ed25519' sops";
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

  # Enable fzf with zsh integration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file = {
    p10k-config = {
      source = ./p10k-config/p10k-config.zsh;
      target = "${config.home.homeDirectory}/.p10k.zsh";
    };
  };
}
