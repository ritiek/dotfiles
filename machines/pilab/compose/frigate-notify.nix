# Frigate (on chocomelt) publishes events to this MQTT broker, and
# frigate-notify forwards its alerts to ntfy.
{ config, lib, homelabMediaPath, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [{
      port = 1883;
      omitPasswordAuth = true;
      settings.allow_anonymous = true;
      acl = [ "topic readwrite #" ];
    }];
  };
  # Started by homelab-start (via docker-frigate-notify), not at boot.
  systemd.services.mosquitto = {
    wantedBy = lib.mkForce [ ];
    unitConfig.ConditionPathIsMountPoint = homelabMediaPath;
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 1883 ];

  sops.secrets."frigate_notify.username" = { };
  sops.secrets."frigate_notify.password" = { };

  sops.templates."frigate-notify.yml" = {
    restartUnits = [ "docker-frigate-notify.service" ];
    content = ''
      # Frigate only creates review items for cameras with recording on, and
      # chocomelt has it off, so "reviews" mode would never fire.
      app:
        mode: events
      frigate:
        server: http://chocomelt.lion-zebra.ts.net
        public_url: http://chocomelt.lion-zebra.ts.net
        username: ${config.sops.placeholder."frigate_notify.username"}
        password: ${config.sops.placeholder."frigate_notify.password"}
        mqtt:
          enabled: true
          server: localhost
          port: 1883
          clientid: frigate-notify
      alerts:
        general:
          notify_once: true
        ntfy:
          enabled: true
          server: http://localhost:8894
          topic: frigate
          # Default action links to a clip, which doesn't exist with recording off.
          headers:
            - Authorization: Bearer ${config.sops.placeholder."ntfy.frigate_token"}
            - X-Click: http://chocomelt.lion-zebra.ts.net/explore?event_id={{ .ID }}
            - X-Actions: view, Open in Frigate, http://chocomelt.lion-zebra.ts.net/explore?event_id={{ .ID }}, clear=true
    '';
  };

  virtualisation.oci-containers.containers."frigate-notify" = {
    image = "ghcr.io/0x2142/frigate-notify:v0.5.4";
    volumes = [
      "${config.sops.templates."frigate-notify.yml".path}:/app/config.yml:ro"
    ];
    environment.TZ = config.time.timeZone;
    log-driver = "journald";
    autoStart = false;
    extraOptions = [ "--network=host" ];
  };
  systemd.services."docker-frigate-notify" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    after = [ "mosquitto.service" "docker-ntfy.service" ];
    requires = [ "mosquitto.service" ];
    unitConfig.ConditionPathIsMountPoint = homelabMediaPath;
  };
}
