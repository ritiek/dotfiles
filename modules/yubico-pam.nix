{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ pam_u2f ];

  users.users.ritiek.extraGroups = lib.mkAfter [ "plugdev" ];

  security = {
    sudo.wheelNeedsPassword = true;
    sudo-rs.wheelNeedsPassword = true;

    pam.sshAgentAuth.enable = true;

    pam.services = {
      login = {
        u2fAuth = true;
        # sshAgentAuth = true;
        # rssh = true;
      };
      sudo = {
        u2fAuth = true;
        # sshAgentAuth = true;
        # rssh = true;
      };
      su = {
        u2fAuth = true;
        # sshAgentAuth = true;
        # rssh = true;
      };
      polkit-1 = {
        u2fAuth = true;
        # sshAgentAuth = true;
        # rssh = true;
      };
      hyprlock = {
        u2fAuth = true;
        # sshAgentAuth = true;
        # rssh = true;
      };
    };

    pam.yubico = {
      enable = true;
      debug = true;
      mode = "challenge-response";
      id = [ "30084843" ];
    };
  };

  services.udev.extraRules = ''
    # Yubikey 5 NFC
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0407", MODE="0664", GROUP="plugdev"

    # Yubikey Security Key C
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0403", MODE="0664", GROUP="plugdev"

    # Yubikey Security Key A
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0402", MODE="0664", GROUP="plugdev"
  '';
}
