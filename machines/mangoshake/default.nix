{ config, pkgs, lib, inputs, ... }:

let
  wifite-preconfig = pkgs.writeShellScriptBin "wifite-preconfig" ''
    ${pkgs.wifite2}/bin/wifite \
      -i $(ls /sys/class/net | grep -vE '^(lo|tailscale0|wlan0)$' | head -n 1) \
      -E $(iwgetid -r) \
      --wpa \
      --no-wps \
      --skip-crack \
      --no-pmkid \
      --showb \
      --allbands \
      --pillage 120 \
      --wpat 99999 \
      --wpadt 90 \
      --num-deauths 10 \
      --hs-dir handshakes

      # --clients-only
  '';
in
{
  imports = [
    ./hw-config.nix
    inputs.sops-nix.nixosModules.sops
    # inputs.impermanence.nixosModules.impermanence
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/wifi.nix
    ./../../modules/tailscale.nix
  ];

  networking.hostName = "mangoshake";
  time.timeZone = "Asia/Kolkata";

  # Needed for building SD images.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;

  # environment.persistence."/nix/persist/system" = {
  #   enable = true; 
  #   hideMounts = true;
  #   directories = [
  #     "/var/lib/nixos"
  #   ];
  #   files = [
  #     "/etc/machine-id"
  #     "/etc/ssh/ssh_host_ed25519_key"
  #     "/etc/ssh/ssh_host_ed25519_key.pub"
  #     "/etc/ssh/ssh_host_rsa_key"
  #     "/etc/ssh/ssh_host_rsa_key.pub"
  #   ];
  # };

  # Disable sudo as we've no non-root users.
  security.sudo.enable = false;

  users = {
    mutableUsers = false;

    users.root = {
      password = "ff";
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
      ];
      packages = with pkgs; [
        screen
        vim
        wifite2
        wifite-preconfig
      ];
    };
  };

  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  programs = {
    zsh.enable = true;
  };

  systemd.services.wifite = {
    enable = true;
    description = "Monitor WPA networks for handshakes.";
    path = [
      pkgs.screen
      wifite-preconfig
    ];
    wantedBy = [ "default.target" ];
    # after = [ "network-online.target" ];
    # wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "forking";
      WorkingDirectory = "/root";
      Environment = "PATH=$PATH:/run/current-system/sw/bin/";
      ExecStart = "${pkgs.screen}/bin/screen -dmS wifite -s ${wifite-preconfig}/bin/wifite-preconfig";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 60;
      # User = "root";
      # Group = "root";
    };
    # script = ''
    #   ${pkgs.screen}/bin/screen -dmS -s "${wifite-preconfig}/bin/wifite-preconfig";
    # '';
  };

  powerManagement.cpuFreqGovernor = "performance";
  zramSwap = {
    enable = true;
    memoryPercent = 200;
  };

  boot.tmp = {
    useTmpfs = true;
    cleanOnBoot = true;
  };

  systemd.watchdog.runtimeTime = "360s";

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
