# alcove - Radxa Cubie A7S (Allwinner A733 / sun60iw2).
# See RADXA_CUBIE_A7S_NIXOS_PLAN.md in the NIXOS_PORTS repo for the full
# bring-up history (custom kernel, vendor U-Boot blobs, out-of-tree
# AIC8800D80 USB WiFi driver). This file follows the same fleet
# conventions as machines/radrubble and machines/chocomelt (sops secrets,
# distributed builds, ritiek/rnixbld users) - see hw-config.nix for the
# board-specific bootloader/kernel/WiFi wiring.
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./home
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/attic-watch-store.nix
    ./../../modules/wifi.nix
    ./../../modules/usbipd.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/netbird.nix
  ];

  sops.secrets = {
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
  };

  networking.hostName = "alcove";
  time.timeZone = "Asia/Kolkata";

  # Needed for the unfree vendor U-Boot blobs (see hw-config.nix).
  nixpkgs.config.allowUnfree = true;

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    users.ritiek = {
      isNormalUser = true;
      password = "ff";
      extraGroups = [
        "wheel"
      ];
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

    users.rnixbld = {
      isSystemUser = true;
      group = "users";
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPlUpYpBOffFgrMAViDxiTCrVCRP6wQIFWd7/KiNkV2"
      ];
    };
  };

  services = {
    openssh = {
      enable = true;
      startWhenNeeded = true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };
    timesyncd.enable = true;
  };

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

  # Ethernet (gmac0/end0, RGMII) is plain DHCP - confirmed reliable with a
  # known-good cable (see plan doc's "Onboard Ethernet reliability -
  # RESOLVED" section; an earlier "unreliable" report was a bad cable, not
  # a driver bug). WiFi (AIC8800D80 over USB, driver wired up in
  # hw-config.nix) is handled by wifi.nix's imperative wpa_supplicant
  # config (matching radrubble/chocomelt's fleet convention) instead of
  # NetworkManager/nmtui now. The actual SSID/PSK live in the sops secret
  # "wpa_supplicant" (-> /etc/wpa_supplicant/imperative.conf), reused
  # as-is from radrubble's secrets.yaml for now - update that secret with
  # this machine's real network once provisioned.
  networking.useDHCP = lib.mkDefault true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # NixOS' "ntfs" filesystem support (nixos/modules/tasks/filesystems/ntfs.nix)
  # is purely a userspace thing - it just installs pkgs.ntfs3g (a FUSE-based
  # mount helper), no in-kernel NTFS driver involved. The real kernel-side
  # requirement is CONFIG_FUSE_FS, added to linux-defconfig.config.
  boot.supportedFilesystems = [ "ntfs" ];

  # Serial console login shell (USB-TTL adapter on UART0, 115200 baud,
  # kernel device /dev/ttyAS0 - Allwinner's own serial driver naming, NOT
  # the generic ttyS0). Forced explicitly rather than relying purely on
  # systemd-getty-generator's automatic console= cmdline detection, so a
  # login shell is guaranteed on every boot with zero network/SSH
  # dependency - see plan doc's "HANG #7" section for why this mattered a
  # lot during bring-up (the serial console never had a real login shell
  # for a long time, purely due to a wrong kernel UART driver, which was a
  # nasty surprise given how similar "just kernel log output" looks to
  # "console works").
  systemd.services."serial-getty@ttyAS0".wantedBy = [ "getty.target" ];

  # Kept at maximum verbosity per explicit user preference from the
  # bring-up phase (see plan doc's "Key NixOS-level settings" section for
  # why a manual loglevel=N kernel param would NOT work here - nixpkgs'
  # kernel.nix module unconditionally appends its own loglevel= derived
  # from this option to the END of boot.kernelParams, and the kernel takes
  # the LAST duplicate cmdline param). Lower this (e.g. to 4) for quieter
  # boot logs if wanted - confirm with whoever's driving this machine
  # first, it was an explicit choice made while debugging several real
  # kernel hangs, not an oversight.
  boot.consoleLogLevel = 8;

  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.settings.Manager.RuntimeWatchdogSec = "360s";

  # Overridden by nixos-generators/the sd-image builder for actual images.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  hardware.enableRedistributableFirmware = true;

  # USB gadget Ethernet over the USB-C port, for first-boot SSH access
  # before real networking/WiFi credentials are provisioned - mirrors
  # radrubble/Zero3's g_ether setup. Requires CONFIG_USB_ETH (g_ether) +
  # CONFIG_USB_GADGET + a UDC driver, all added to
  # linux-defconfig-fragment.config (DWC3 in dual-role mode already
  # provides the UDC, see hw-config.nix's USB_DWC3_DUAL_ROLE comments).
  boot.kernelModules = [ "g_ether" ];
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.2";
    prefixLength = 24;
  }];

  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    iproute2
    curl
    ethtool
    # Added during bring-up to debug the onboard Ethernet PHY over MDIO
    # (now resolved - it was a bad cable, see plan doc). Harmless/cheap to
    # keep for any future diagnostics; remove if a leaner image is wanted.
    mdio-tools
    phytool
  ];

  system.stateVersion = "25.11";
}
