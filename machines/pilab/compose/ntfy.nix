# ntfy push notifications. Every publisher gets its own user with write-only
# access to its topic plus an access token; `ritiek` is the admin/subscriber.
{ config, lib, homelabMediaPath, ... }:

let
  # ntfy user -> topic it may publish to
  publishers = {
    frigate = "frigate";
    qbittorrent = "qbittorrent";
    gatus = "gatus";
    uptime_kuma = "uptime-kuma";
    radarr = "arr";
    sonarr = "arr";
    prowlarr = "arr";
    bazarr = "arr";
    jellyfin = "jellyfin";
    seerr = "seerr";
    changedetection = "changedetection";
  };
  users = [ "ritiek" ] ++ lib.attrNames publishers;
  ph = name: config.sops.placeholder."ntfy.${name}";
  join = f: lib.concatStringsSep "," (map f (lib.attrNames publishers));
in
{
  sops.secrets = lib.genAttrs
    ([ "ntfy.admin_password_hash" "ntfy.publisher_password_hash" ]
      ++ map (u: "ntfy.${u}_token") users)
    (_: { });

  sops.templates."ntfy.env" = {
    restartUnits = [ "docker-ntfy.service" ];
    content = ''
      NTFY_AUTH_USERS=ritiek:${ph "admin_password_hash"}:admin,${join (u: "${u}:${ph "publisher_password_hash"}:user")}
      NTFY_AUTH_TOKENS=${lib.concatMapStringsSep "," (u: "${u}:${ph "${u}_token"}") users}
    '';
  };

  virtualisation.oci-containers.containers."ntfy" = {
    image = "binwiederhier/ntfy:v2.34.0";
    cmd = [ "serve" ];
    environment = {
      TZ = config.time.timeZone;
      NTFY_BASE_URL = "http://pilab.lion-zebra.ts.net:8894";
      NTFY_CACHE_FILE = "/var/lib/ntfy/cache.db";
      NTFY_ATTACHMENT_CACHE_DIR = "/var/lib/ntfy/attachments";
      NTFY_AUTH_FILE = "/var/lib/ntfy/auth.db";
      NTFY_AUTH_DEFAULT_ACCESS = "deny-all";
      NTFY_AUTH_ACCESS = join (u: "${u}:${publishers.${u}}:wo");
      NTFY_ENABLE_LOGIN = "true";
    };
    environmentFiles = [ config.sops.templates."ntfy.env".path ];
    volumes = [
      "${homelabMediaPath}/services/ntfy:/var/lib/ntfy:rw"
    ];
    ports = [
      "8894:80/tcp"
    ];
    user = "1000:1000";
    log-driver = "journald";
    autoStart = false;
    labels = {
      "homepage.description" = "Send push notifications";
      "homepage.group" = "Monitoring";
      "homepage.href" = "http://pilab.lion-zebra.ts.net:8894";
      "homepage.icon" = "ntfy";
      "homepage.name" = "ntfy";
    };
  };
  systemd.services."docker-ntfy" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
      RestartMaxDelaySec = lib.mkOverride 500 "1m";
      RestartSec = lib.mkOverride 500 "100ms";
      RestartSteps = lib.mkOverride 500 9;
    };
    unitConfig = {
      RequiresMountsFor = [ "${homelabMediaPath}/services/ntfy" ];
      ConditionPathIsMountPoint = homelabMediaPath;
    };
  };
}
