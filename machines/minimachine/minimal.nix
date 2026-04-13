{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./../../modules/nix.nix
  ];

  networking.hostName = "minimachine";
  networking.interfaces."wlan0".useDHCP = true;
  networking.wireless = {
    enable = true;
    interfaces = [ "wlan0" ];
    # FIXME: Add in correct WiFi creds before building the image.
    networks = {
      "SSID".psk = "PASSWORD";
    };
  };
  time.timeZone = "Asia/Kolkata";

  nixpkgs.config.allowUnsupportedSystem = true;

  users = {
    mutableUsers = false;
    users.ritiek = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # password = "raspberry";
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
      ];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 500;
  };

  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  documentation = {
    enable = false;
    man.enable = false;
    doc.enable = false;
    dev.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  system.stateVersion = "25.05";
}
