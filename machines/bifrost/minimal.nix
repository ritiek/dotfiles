{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/netbird.nix
    ./../../modules/tailscale-controlplane.nix
  ];

  networking.hostName = "bifrost";
  networking.usePredictableInterfaceNames = true;

  # Consumed as the EnvironmentFile of NetworkManager-ensure-profiles, a oneshot
  # that substitutes these values into the keyfiles when it runs. Rotating the
  # WiFi credentials is a no-op until that unit runs again.
  sops.secrets."networkmanager.profiles" = {
    restartUnits = [ "NetworkManager-ensure-profiles.service" ];
  };

  networking.networkmanager = {
    enable = true;
    ensureProfiles = {
      environmentFiles = [ config.sops.secrets."networkmanager.profiles".path ];
      profiles = {
        "primary" = {
          connection = {
            id = "primary";
            type = "wifi";
            interface-name = "wlan0";
          };
          wifi = {
            mode = "infrastructure";
            ssid = "$WIFI_SSID_PRIMARY";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$WIFI_PSK_PRIMARY";
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
        "secondary" = {
          connection = {
            id = "secondary";
            type = "wifi";
            # Omitting `interface-name` here so this profile can bind to any
            # wifi device other than the one pinned to "primary" (wlan0).
            # multi-connect = "3" (NM_CONNECTION_MULTI_CONNECT_MULTIPLE) lets
            # it be simultaneously active on more than one device at once
            # (e.g. both wlan1 and wlu1), instead of NM's default of only
            # ever activating a given profile on a single device at a time.
            multi-connect = "3";
          };
          wifi = {
            mode = "infrastructure";
            ssid = "$WIFI_SSID_SECONDARY";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$WIFI_PSK_SECONDARY";
          };
          ipv4.method = "auto";
          ipv6.method = "ignore";
        };
      };
    };
  };
  time.timeZone = "Asia/Kolkata";

  nixpkgs.config.allowUnsupportedSystem = true;

  users = {
    mutableUsers = false;
    users.ritiek = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = "raspberry";
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
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group-exchange-sha256"
        ];
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
