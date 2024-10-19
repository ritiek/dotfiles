{
  networking.hostName = "minimal";

  # Helpful for tinkering within the installation environment.
  # fileSystems."/root" = {
  #   device = "none";
  #   fsType = "tmpfs";
  #   options = [
  #     "size=2G"
  #     "mode=755"
  #   ];
  # };

  # Swap files don't work as expected as they seem to use tmpfs.
  #
  # swapDevices = [{
  #   device = "/swap";
  #   size = 2 * 1024;  # 2GB
  # }];
  #
  # disko.devices.disk.minimal = {
  #   device = "nodev";
  #   content = {
  #     type = "gpt";
  #     partitions = {
  #       plain-swap = {
  #         size = "2G";
  #         content = {
  #           type = "swap";
  #           discardPolicy = "both";
  #           resumeDevice = true;
  #         };
  #       };
  #     };
  #   };
  # };
  #
  # disko.devices.nodev = {
  #   "/swap" = {
  #     fsType = "ext4";
  #     mountOptions = [
  #       "size=2G"
  #       "mode=755"
  #     ];
  #   };
  # };

  # systemd.tmpfiles.rules = [
  #     "f /var/log/timers/backup - ${variables.username} ${variables.username} - -"
  # ];

  # systemd.tmpfiles.settings."swap" = {
  #   "/var/lib/swap" = {
  #     f = {
  #       group = "root";
  #       mode = "0755";
  #       user = "root";
  #     };
  #   };
  # };

  # Disable sudo as we've no non-root users.
  security.sudo.enable = false;

  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
  ];

  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  powerManagement.cpuFreqGovernor = "performance";

  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  nix.settings.auto-optimise-store = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
