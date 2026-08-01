{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./home
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    inputs.kvmd-nix.nixosModules.kvmd
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/wifi/network_manager.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/netbird.nix
    ./../../modules/usbipd.nix
  ];

  networking.hostName = lib.mkDefault "zerokvm";
  time.timeZone = lib.mkDefault "Asia/Kolkata";

  boot.supportedFilesystems = [ "ntfs" ];

  nix = {
    distributedBuilds = true;
    buildMachines = [{
      hostName = "pilab.lion-zebra.ts.net";
      system = "aarch64-linux";
      protocol = "ssh";
      sshUser = "ritiek";
      maxJobs = 8;
      speedFactor = 5;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    }];
  };

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    users.ritiek = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      # OS login password, used for both console/ttyd login on this
      # headless KVM appliance (carried over from nixkvm; every other
      # /etc/nixos machine is SSH-key-only, but this one deliberately
      # keeps a console/ttyd fallback for physical access).
      password = "pikvm";
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
      ];
      packages = [
        inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
  };

  services = {
    openssh = {
      enable = true;
      startWhenNeeded = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };

    avahi = {
      enable = true;
      openFirewall = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    ttyd = {
      enable = true;
      writeable = true;
      # Log in to the ttyd web terminal as our own user (not root),
      # matching the password set above.
      user = "ritiek";
    };
  };

  networking.firewall.allowedTCPPorts = [ 7681 ];

  # ttyd from the current nixpkgs (448d6256) is broken on aarch64: it dies at
  # startup with
  #   E: lws_create_context: failed to load evlib_uv
  #   E: libwebsockets context creation failed
  # libwebsockets dlopens its event-loop backend as a plugin, and that lookup
  # fails in that revision. The plugin .so is present and its libuv dep
  # resolves, so this is a plugin-search-path bug in the packaging rather than
  # a missing dependency. The same ttyd version (1.7.7) built from the pinned
  # nixpkgs-pikvm revision starts fine — verified by running both binaries
  # directly on the device.
  #
  # This is an overlay rather than `services.ttyd.package` because kvmd-nix's
  # webterm module hardcodes `${pkgs.ttyd}/bin/ttyd` (modules/kvmd/webterm.nix)
  # with no package option, so both ttyd.service and kvmd-webterm.service need
  # to resolve to the working build. Keeping ttyd alive matters more than the
  # web UI's Terminal tab: this box is WiFi-only with no ethernet, and ttyd is
  # the out-of-band way in (hence the hardcoded console password above) if
  # NetworkManager or sshd ever fails to come up.
  #
  # Drop this once ttyd/libwebsockets works in the shared nixpkgs again. It is
  # independent of the kernel pins — pkgsPikvm in hw-config.nix imports its
  # nixpkgs without overlays, so the kernel derivation hash is unaffected.
  nixpkgs.overlays = [
    (final: prev: {
      ttyd = (import inputs.nixpkgs-pikvm {
        inherit (prev.stdenv.hostPlatform) system;
      }).ttyd;
    })
  ];

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
  };

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  powerManagement.cpuFreqGovernor = "performance";
  zramSwap = {
    enable = true;
    memoryPercent = 90;
    algorithm = "zstd";
  };

  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.settings.Manager.RuntimeWatchdogSec = 360;

  # Save storage space
  documentation = {
    enable = false;
    man.enable = false;
    doc.enable = false;
    dev.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "25.11";
}
