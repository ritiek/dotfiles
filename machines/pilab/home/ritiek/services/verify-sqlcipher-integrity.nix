{ config, pkgs, lib, inputs, ... }:

let
  verify-sqlcipher-integrity = (pkgs.writeShellScriptBin "verify-sqlcipher-integrity" ''
      ${pkgs.unzip}/bin/unzip -qq -o \
        $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."path-to-sqlcipher-zip.txt".path}) \
        "*.db" \
        -d /tmp/verify-sqlcipher-integrity \
      > /dev/null 2>&1

      unzip_exit_code=$?

      if [ $unzip_exit_code -ne 0 ]; then
        ${pkgs.coreutils}/bin/rm -rf /tmp/verify-sqlcipher-integrity/*.db
        ${pkgs.coreutils}/bin/echo "Unzip failed with exit code: $unzip_code_code."
        exit $unzip_exit_code
      fi

      for cipher_db in /tmp/verify-sqlcipher-integrity/*.db; do
        ${pkgs.sqlcipher}/bin/sqlcipher $cipher_db \
        "PRAGMA key=\"$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."sqlcipher.key".path})\"; SELECT type FROM sqlite_master LIMIT 1;" \
        > /dev/null

        sqlcipher_exit_code=$?

        if [ $sqlcipher_exit_code -ne 0 ]; then
          ${pkgs.coreutils}/bin/rm -rf /tmp/verify-sqlcipher-integrity/*.db
          ${pkgs.coreutils}/bin/echo "SQLCipher integrity check failed."
          exit $sqlcipher_exit_code
        fi
      done;

      ${pkgs.coreutils}/bin/rm -rf /tmp/verify-sqlcipher-integrity/*.db
      ${pkgs.coreutils}/bin/echo "SQLCipher integrity check succeeded."
  '');

  ping-uptime-kuma = (pkgs.writeShellScriptBin "ping-uptime-kuma@sqlcipher-integrity" ''
    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    source "${config.home.homeDirectory}/.config/sops-nix/secrets/uptime-kuma.env"

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/VxzbnLNAau?status=$STATUS&msg=$SERVICE_RESULT&ping="
    curl_exit_code=$?

    if [ $curl_exit_code -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma succeeded."
    else
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma failed."
      exit $curl_exit_code
    fi
  '');
in
{
  sops.secrets."sqlcipher.key" = {};
  sops.secrets."path-to-sqlcipher-zip.txt" = {};
  sops.secrets."uptime-kuma.env" = {};

  home.packages = with pkgs; [
    verify-sqlcipher-integrity
    curl
    jq
  ];

  systemd.user.services.verify-sqlcipher-integrity = {
    Unit = {
      Description = "Check if an SQLCipher's db is tied to a given secret key";
      RequiresMountsFor = [
        "/media/HOMELAB_MEDIA"
      ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "/media/HOMELAB_MEDIA";
      ExecStart = "${verify-sqlcipher-integrity}/bin/verify-sqlcipher-integrity";
      ExecStopPost = "${ping-uptime-kuma}/bin/ping-uptime-kuma@sqlcipher-integrity";
    };
  };

  systemd.user.timers.verify-sqlcipher-integrity = {
    Unit = {
      Description = "Periodically check if an SQLCipher's db is tied to a given secret key";
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "6h";
      Unit = "verify-sqlcipher-integrity.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
