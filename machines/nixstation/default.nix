{ config, pkgs, lib, inputs, ... }:

# PS4 (Baikal southbridge) booted via GoldHEN + ps4-linux-loader payload.
# The payload loads bzImage + initramfs.cpio.gz (initramfs-ps4) from the FAT
# partition on the USB SSD. initramfs-ps4 mounts the ext4 partition labelled
# `psxitarch` and switch_roots into /sbin/init, which boot.loader.initScript
# points at the current generation. Kernel cmdline lives in bootargs.txt on
# the FAT partition, so boot.kernelParams has no effect here.
let
  # Mesa with Liverpool/Gladius chip IDs (from DionKill's mesa-ps4), built
  # with only the drivers this GPU can use to keep the local build short.
  ps4Mesa =
    mesa:
    (mesa.override {
      galliumDrivers = [ "radeonsi" "llvmpipe" "zink" ];
      vulkanDrivers = [ "amd" "swrast" ];
    }).overrideAttrs
      (o: {
        patches = (o.patches or [ ]) ++ [ ./mesa-ps4.patch ];
        # spirv2dxil output stays empty without the d3d12 drivers.
        postInstall = o.postInstall + "\nmkdir -p $spirv2dxil\n";
      });
in
{
  imports = [
    inputs.nix-index-database.nixosModules.nix-index
    inputs.sops-nix.nixosModules.sops
    ./home
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/ssh.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/netbird.nix
    ./../../modules/3proxy.nix
    ./../../modules/attic-watch-store.nix
    ./../../modules/net-tuning.nix
    ./../../modules/wifi/network-manager.nix
  ];

  # Kernel is the prebuilt Strawberry 7.0.8 Baikal bzImage (nearly everything
  # built in, Wi-Fi firmware embedded), so NixOS ships no kernel or initrd.
  boot.kernel.enable = false;
  boot.initrd.enable = false;
  boot.loader.grub.enable = false;
  boot.loader.initScript.enable = true;

  # initramfs-ps4 mounts LABEL=psxitarch as-is (top-level subvolume, default
  # options); systemd-remount-fs applies these options afterwards.
  fileSystems."/" = {
    device = "/dev/disk/by-label/psxitarch";
    fsType = "btrfs";
    # Same as pilab's btrfs mounts. `ssd` because the USB bridge reports the
    # SSD as rotational.
    options = [
      "noatime"
      "nodiscard"
      "noautodefrag"
      "ssd"
      "space_cache=v2"
      "compress-force=zstd:3"
    ];
  };

  services.btrfs.autoScrub.enable = true;

  networking.hostName = "nixstation";
  time.timeZone = "Asia/Kolkata";

  # Kernel is built without CONFIG_NETFILTER: no firewall, and tailscale
  # can't touch iptables or act as an exit node.
  networking.firewall.enable = false;
  services.tailscale = {
    # tailscaled always probes `iptables --version` at startup; the nft
    # backend fails without kernel support, legacy just prints the version.
    package = pkgs.tailscale.override { iptables = pkgs.iptables-legacy; };
    useRoutingFeatures = lib.mkForce "none";
    extraUpFlags = lib.mkForce [
      "--login-server=https://controlplane.clawsiecats.omg.lol"
      "--netfilter-mode=off"
      "--reset"
    ];
  };

  sops.secrets = {
    ritiek_password_hash.neededForUsers = true;
    # Presence of these enables the nixbuild/nixbuild2/nixbuild3 wrappers in modules/nix.nix.
    "rnixbld.id_ed25519" = { mode = "600"; owner = "root"; group = "nixbld"; };
    "nixbuild2.id_ed25519" = { mode = "600"; owner = "root"; group = "nixbld"; };
    "nixbuild3.id_ed25519" = { sopsFile = ../nixbuild3.yaml; mode = "600"; owner = "root"; group = "nixbld"; };
  };

  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
    users.ritiek = {
      isNormalUser = true;
      description = "Ritiek Malhotra";
      hashedPasswordFile = config.sops.secrets.ritiek_password_hash.path;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
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

  security = {
    # deploy-rs activates over non-interactive sudo.
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;
    polkit.enable = true;
    pam.services.hyprlock = { };
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  nixpkgs.config.allowUnfree = true;

  # radeonsi doesn't know the PS4 GPU (Liverpool/Gladius); patch from
  # github.com/DionKill/ps4-video-archlinux (mesa-ps4), rebased on nixpkgs mesa.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    package = ps4Mesa pkgs.mesa;
    package32 = ps4Mesa pkgs.pkgsi686Linux.mesa;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    wlr.enable = true;
    config = {
      common.default = [ "hyprland" ];
      niri.default = [ "gtk" "hyprland" ];
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
    nix-ld.enable = true;
    # Gamescope currently doesn't work:
    # https://github.com/NixOS/nixpkgs/issues/292620
    # gamescope = {
    #   enable = true;
    #   capSysNice = true;
    # };
    steam = {
      enable = true;
      # gamescopeSession.enable = true;
    };
    gamemode = {
      enable = true;
      enableRenice = true;
    };
  };

  environment.systemPackages = with pkgs; [
    git
    htop
    pciutils
    usbutils
    dconf
    swayosd
    libnotify
    xdg-utils
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      cantarell-fonts
      material-design-icons
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      nerd-fonts.fantasque-sans-mono
      nerd-fonts.inconsolata-go
      nerd-fonts.jetbrains-mono
    ];
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General = {
      Enable = "Source,Sink,Media,Socket";
      Experimental = true;
    };
  };

  services = {
    udev.packages = [ pkgs.swayosd ];
    udisks2.enable = true;
    upower.enable = true;
    blueman.enable = true;
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };

  gtk.iconCache.enable = true;
  documentation.enable = false;
  zramSwap.enable = true;

  # console=ttyS0 is in the payload's cmdline, but the PS4 UART isn't usable; getty restart-loops.
  systemd.services."serial-getty@ttyS0".enable = false;

  system.stateVersion = "26.11";
}
