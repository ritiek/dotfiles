{
  environment.persistence."/nix/persist/system" = {
    enable = true;  # NB: Defaults to true, not needed
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/var/log"
      # "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      # "/etc/NetworkManager/system-connections"
      # { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
    ];
    files = [
      # "/etc/machine-id"
      # { file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
    ];
    # users.talyz = {
    #   directories = [
    #     "Downloads"
    #     "Music"
    #     "Pictures"
    #     "Documents"
    #     "Videos"
    #     "VirtualBox VMs"
    #     { directory = ".gnupg"; mode = "0700"; }
    #     { directory = ".ssh"; mode = "0700"; }
    #     { directory = ".nixops"; mode = "0700"; }
    #     { directory = ".local/share/keyrings"; mode = "0700"; }
    #     ".local/share/direnv"
    #   ];
    #   files = [
    #     ".screenrc"
    #   ];
    # };
  };
}
