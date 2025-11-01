{ config, ... }:

{
  home.persistence."/nix/persist/home/${config.home.username}" = {
    directories = [
      ".ssh"
      ".gnupg"
      ".local/share/nvim"
      ".local/share/zellij"
      ".local/share/direnv"
      ".local/share/keyrings"
      ".config/sops"
      ".config/niri"
      ".config/ghostty"
      ".config/hypr"
      ".mozilla"
      ".zen"
      ".librewolf"
      ".thunderbird"
      ".config/Joplin"
      ".config/freetube"
      ".config/calibre"
      ".android"
      ".gradle"
      ".cargo"
      ".rustup"
      
      "Downloads"
      "Documents"
      "Pictures"
      "Videos"
      "Music"
      
      ".docker"
      
      ".local/share/Steam"
      ".local/share/lutris"
    ];
    files = [
      ".zsh_history"
      ".bash_history"
      ".claude.json"
    ];
    allowOther = true;
  };
}