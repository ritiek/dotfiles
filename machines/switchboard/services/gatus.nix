# Native Gatus, replacing pilab's dockerized uptime-kuma container.
#
# All of pilab's uptime-kuma monitors have been migrated here (excluding
# pure UI "group" placeholders, which had no check of their own -- Gatus's
# `group` field on each endpoint recreates that grouping natively).
#
# Pull-type checks (ping/http) are recreated as `endpoints`. Push/heartbeat
# monitors are recreated as `external-endpoints` (Gatus's equivalent of
# uptime-kuma's push monitors: POST /api/v1/endpoints/{key}/external).
# Per user decision, the cron/scripts that used to POST to uptime-kuma are
# NOT updated yet -- these external-endpoints are declared/ready but
# nothing calls them yet. Note that Gatus only evaluates alerting for an
# external-endpoint when a push actually arrives, so this is safe: no
# false "missed heartbeat" alarms until the scripts are actually migrated.
#
# Monitors that were already INACTIVE in uptime-kuma (ballistica-archive,
# spotdl-sync, sqlcipher-integrity) are migrated with `enabled = false` to
# preserve parity -- flip to `true` to reactivate them.
#
# Notifications are migrated 1:1 from pilab's uptime-kuma (see its
# `notification`/`monitor_notification` tables): Gotify is attached to the
# same 7 push monitors, and email/SMTP (Mailgun) is attached only to
# ballistica-archive. Discord was skipped since it wasn't attached to any
# monitor on pilab (isDefault=false, no monitor_notification rows).
{ config, ... }:
{
  sops.secrets."gatus.env" = { };

  services.gatus = {
    enable = true;
    openFirewall = true;
    environmentFile = config.sops.secrets."gatus.env".path;

    settings = {
      web.port = 8080;

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      # Notifications, migrated 1:1 from pilab's uptime-kuma. Discord was
      # skipped since it isn't attached to any monitor on pilab. Gotify
      # (priority=2, same as pilab) is attached to the 7 push monitors
      # that had it in uptime-kuma; email/SMTP (Mailgun) is attached only
      # to ballistica-archive, same as pilab.
      alerting = {
        gotify = {
          "server-url" = "http://pilab.lion-zebra.ts.net:8893";
          token = "\${GATUS_GOTIFY_TOKEN}";
          priority = 2;
        };
        email = {
          from = "\"Gatus (switchboard)\" <uptime-kuma@pi400kb>";
          username = "postmaster@sandboxf0abdf5a040d402ab4c9cf35b2535bf4.mailgun.org";
          password = "\${GATUS_SMTP_PASSWORD}";
          host = "smtp.mailgun.org";
          port = 587;
          to = "ritiekmalhotra123@gmail.com";
        };
      };

      endpoints = [
        # Tailnet hosts
        {
          name = "keyberry";
          group = "tailnet";
          url = "icmp://keyberry.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "clawsiecats";
          group = "tailnet";
          url = "icmp://clawsiecats.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "mishy";
          group = "tailnet";
          url = "icmp://mishy.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "rig";
          group = "tailnet";
          url = "icmp://rig.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "frigate";
          group = "tailnet";
          url = "icmp://frigate.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "deskette";
          group = "tailnet";
          url = "icmp://deskette.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "alcove";
          group = "tailnet";
          url = "icmp://alcove.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "radrubble";
          group = "tailnet";
          url = "icmp://radrubble.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "switchboard";
          group = "tailnet";
          url = "icmp://switchboard.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "chocomelt";
          group = "tailnet";
          url = "icmp://chocomelt.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "zerokvm";
          group = "tailnet";
          url = "icmp://zerokvm.lion-zebra.ts.net";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          # Inactive on pilab's uptime-kuma; migrated disabled to preserve
          # parity. Set enabled=true to reactivate.
          name = "ballistica-archive";
          group = "tailnet";
          enabled = false;
          url = "https://ballistica-archive.drake-skate.ts.net/";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [ { type = "email"; } ];
        }

        # LAN hosts
        {
          name = "redmi-note-11";
          group = "lan";
          url = "icmp://192.168.2.15";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "m2";
          group = "lan";
          url = "icmp://192.168.2.9";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "pratiek-room-esp8266";
          group = "lan";
          url = "icmp://192.168.1.5";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "home-assistant-zero-w";
          group = "lan";
          url = "icmp://192.168.1.14";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "outside-area-esp8266";
          group = "lan";
          url = "icmp://192.168.1.6";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "modem";
          group = "lan";
          url = "icmp://192.168.1.1";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "proxmox-miner";
          group = "lan";
          url = "icmp://192.168.1.99";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "hiveos";
          group = "lan";
          url = "icmp://192.168.1.18";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "windows";
          group = "lan";
          url = "icmp://192.168.1.34";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "proxmox-minipc";
          group = "lan";
          url = "icmp://192.168.1.149";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "home-assistant";
          group = "lan";
          url = "icmp://192.168.1.151";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }

        # External / VPN
        {
          name = "clawsiecats.lol";
          group = "external";
          url = "icmp://clawsiecats.lol";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
        {
          name = "drouter";
          group = "netbird";
          url = "icmp://101.64.0.242";
          interval = "60s";
          conditions = [ "[CONNECTED] == true" ];
        }
      ];

      external-endpoints = [
        {
          name = "paperless-ngx-sync";
          group = "backups";
          token = "\${GATUS_TOKEN_PAPERLESS_NGX_SYNC}";
          heartbeat.interval = "3h";
          alerts = [ { type = "gotify"; } ];
        }
        {
          name = "whatsapp-backup-verify";
          group = "backups";
          token = "\${GATUS_TOKEN_WHATSAPP_BACKUP_VERIFY}";
          heartbeat.interval = "16h";
          alerts = [ { type = "gotify"; } ];
        }
        {
          name = "restic-backups-homelab@pilab";
          group = "backups";
          token = "\${GATUS_TOKEN_RESTIC_PILAB}";
          heartbeat.interval = "16h";
          alerts = [ { type = "gotify"; } ];
        }
        {
          name = "restic-backups-homelab@keyberry";
          group = "backups";
          token = "\${GATUS_TOKEN_RESTIC_KEYBERRY}";
          heartbeat.interval = "60h";
          alerts = [ { type = "gotify"; } ];
        }
        {
          # No Gotify on pilab for this one -- left without alerting to
          # match.
          name = "bme680-sensor";
          group = "telemetry";
          token = "\${GATUS_TOKEN_BME680_SENSOR}";
          heartbeat.interval = "10m";
        }
        {
          name = "pihole-local-dns-resolution";
          group = "telemetry";
          token = "\${GATUS_TOKEN_PIHOLE_DNS_CHECK}";
          heartbeat.interval = "8h";
          alerts = [ { type = "gotify"; } ];
        }
        {
          # No Gotify on pilab for this one -- left without alerting to
          # match.
          name = "dht22-sensor";
          group = "telemetry";
          token = "\${GATUS_TOKEN_DHT22_SENSOR}";
          heartbeat.interval = "16h";
        }
        # Inactive on pilab's uptime-kuma; migrated disabled to preserve
        # parity. Set enabled=true (and start calling the push URL) to
        # reactivate.
        {
          name = "spotdl-sync";
          group = "sync";
          enabled = false;
          token = "\${GATUS_TOKEN_SPOTDL_SYNC}";
          heartbeat.interval = "48h";
          alerts = [ { type = "gotify"; } ];
        }
        {
          name = "sqlcipher-integrity";
          group = "backups";
          enabled = false;
          token = "\${GATUS_TOKEN_SQLCIPHER_INTEGRITY}";
          heartbeat.interval = "12h";
          alerts = [ { type = "gotify"; } ];
        }
      ];
    };
  };
}
