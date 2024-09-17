{ config, lib, pkgs, ... }:

{
  imports = [
    ./default.nix
  ];

  environment.persistence."/nix/persist/system" = {
    enable = true; 
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/ssh"
      "/var/log"
      "/var/lib/acme"
      "/var/lib/jitsi-meet"
      "/var/lib/prosody"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
    ];
    users.root = {
      home = "/root";
      files = [
        ".age-key"
      ];
    };
  };
}
