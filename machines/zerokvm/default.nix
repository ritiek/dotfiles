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

  # kvmd's web UI auth. Without this, htpasswdFile defaults to the example file
  # shipped in the kvmd package, which is the well-known admin/admin credential.
  # Only the kvmd daemon itself reads this (kvmd-vnc/kvmd-ipmi would need the
  # kvmd-selfauth group, but both are disabled here).
  #
  # restartUnits is load-bearing. kvmd reads the *path* out of its config once at
  # startup (the auth plugin then re-reads the file's contents on every login),
  # and nothing else here makes systemd restart it: switching htpasswdFile only
  # rewrites /etc/kvmd/override.d/00-nixos-paths.yaml, and NixOS restarts units
  # on unit-definition changes, not /etc changes. Without this, activation
  # succeeds and the old credentials keep working until the next reboot.
  #
  # Note that kvmd strips bcrypt from its accepted hash schemes (kvmd/crypto.py),
  # so an `htpasswd -B` hash silently fails to verify. Generate the secret's
  # contents with a scheme it does accept, e.g.:
  #   echo 'yourpassword' | mkpasswd -m sha-512 -s | sed 's/^/user:/'
  sops.secrets."pikvm.htpasswd" = {
    owner = "kvmd";
    restartUnits = [ "kvmd.service" ];
  };
  services.kvmd.htpasswdFile = config.sops.secrets."pikvm.htpasswd".path;

  # ttyd is unusable with nixpkgs' libwebsockets as packaged — it dies at
  # startup with
  #   E: lws_create_context: failed to load evlib_uv
  #   E: libwebsockets context creation failed
  # libwebsockets dlopens its event-loop backend (evlib_uv) as a plugin, and the
  # directory it searches is built by libwebsockets' CMake as
  # ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}. nixpkgs' cmake hook passes
  # an *absolute* CMAKE_INSTALL_LIBDIR, so the two concatenate into a doubled
  # nonsense path:
  #   /nix/store/<hash>-libwebsockets-4.4.5//nix/store/<hash>-libwebsockets-4.4.5/lib
  # (visible with `strings libwebsockets.so.20`). The plugin .so itself is
  # present in $out/lib and its libuv dep resolves fine — only the lookup path
  # is wrong. Forcing a relative LIBDIR makes it resolve, verified by running
  # the resulting binary: it reaches "elops_init_pt_uv: Using foreign event
  # loop" and listens.
  #
  # This is an overlay rather than `services.ttyd.package` because kvmd-nix's
  # webterm module hardcodes `${pkgs.ttyd}/bin/ttyd` (modules/kvmd/webterm.nix)
  # with no package option, so both ttyd.service and kvmd-webterm.service need
  # to resolve to the fixed build. Keeping ttyd alive matters more than the web
  # UI's Terminal tab: this box is WiFi-only with no ethernet, and ttyd is the
  # out-of-band way in (hence the hardcoded console password above) if
  # NetworkManager or sshd ever fails to come up.
  #
  # Overriding libwebsockets rather than ttyd because the bug is in
  # libwebsockets; anything else linking it gets the fix too. Drop this once
  # nixpkgs fixes libwebsockets upstream. It does not affect the kernel: the
  # kernel comes from nixos-hardware's kernel.nix, which doesn't touch
  # libwebsockets.
  nixpkgs.overlays = [
    (final: prev: {
      libwebsockets = prev.libwebsockets.overrideAttrs (old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_INSTALL_LIBDIR=lib" ];
      });
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

  powerManagement.cpuFreqGovernor = "schedutil";
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
