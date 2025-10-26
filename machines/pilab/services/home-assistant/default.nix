{ config, pkgs, lib, ... }:

{
  # Home Assistant configuration - SOPS encrypted
  # Edit config: cd /etc/nixos && sops-ssh-home machines/pilab/services/home-assistant/configuration.yaml
  # All secrets go directly in configuration.yaml (no separate secrets.yaml needed)

  # Decrypt entire HA configuration file
  # systemd.services.home-assistant-config = {
  #   description = "Decrypt Home Assistant configuration";
  #   wantedBy = [ "home-assistant.service" ];
  #   before = [ "home-assistant.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };
  #   script = ''
  #     mkdir -p /var/lib/hass
  #     export SOPS_AGE_KEY_CMD="${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key"
  #     ${pkgs.sops}/bin/sops -d ${./configuration.yaml} > /var/lib/hass/configuration.yaml
  #     chown hass:hass /var/lib/hass/configuration.yaml
  #     chmod 0600 /var/lib/hass/configuration.yaml
  #   '';
  # };

  sops.secrets."configuration" = {
    sopsFile = ./configuration.yaml;
    owner = "hass";
    group = "hass";
    path = "/var/lib/hass/configuration.yaml";
    restartUnits = [ "home-assistant.service" ];
  };

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "127.0.0.1";
        port = 1883;
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  services.home-assistant = {
    enable = true;

    extraComponents = [
      "met"
      "esphome"
      "mqtt"
      "radio_browser"
      "pi_hole"
      "immich"
      "mobile_app"
    ];

    extraPackages = python3Packages: with python3Packages; [
      pynacl
      pyjwt
    ];

    config = null;

    # Config is managed via SOPS-encrypted file, not writable via UI
    configWritable = false;
  };

  networking.firewall.allowedTCPPorts = [ 8123 ];
}
