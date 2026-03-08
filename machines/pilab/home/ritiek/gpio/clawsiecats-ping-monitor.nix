{ config, pkgs, lib, enableLEDs, ... }:

let
  ping-monitor-loop = pkgs.writeShellScriptBin "clawsiecats-ping-monitor-loop" ''
    TARGET="clawsiecats.lol"
    RETRIES=4
    RETRY_INTERVAL=30
    SLEEP_INTERVAL=60

    echo "clawsiecats.lol ping monitor starting..."

    while true; do
      echo ""
      echo "Pinging $TARGET ($RETRIES retries, ''${RETRY_INTERVAL}s interval)..."

      success=false
      for attempt in $(${pkgs.coreutils}/bin/seq 1 "$RETRIES"); do
        echo "  Attempt $attempt/$RETRIES..."
        if ${pkgs.iputils}/bin/ping -c 1 -W 5 "$TARGET" > /dev/null 2>&1; then
          echo "$TARGET is reachable"
          success=true
          # Turn off solid red LED on success.
          ${lib.optionalString enableLEDs ''
          ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 27=0
          ''}
          break
        fi
        echo "  No response, waiting ''${RETRY_INTERVAL}s before retry..."
        ${pkgs.coreutils}/bin/sleep "$RETRY_INTERVAL"
      done

      source ${config.sops.secrets."uptime-kuma.env".path}
      if [ "$success" = true ]; then
        ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/Ir6oz6IbFN?status=up&msg=OK&ping=" || true
      else
        echo "$TARGET is unreachable"
        ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/Ir6oz6IbFN?status=down&msg=Unreachable&ping=" || true
        # Turn on solid red LED on failure.
        ${lib.optionalString enableLEDs ''
        ${pkgs.libgpiod}/bin/gpioset -t 0 -c gpiochip0 27=1
        ''}
      fi

      echo "Cycle complete, sleeping ''${SLEEP_INTERVAL}s..."
      ${pkgs.coreutils}/bin/sleep "$SLEEP_INTERVAL"
    done
  '';
in
{
  sops.secrets."uptime-kuma.env" = {
    sopsFile = ../secrets.yaml;
  };

  systemd.user.services.clawsiecats-ping-monitor = {
    Unit = {
      Description = "Ping monitor for clawsiecats.lol";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = "${ping-monitor-loop}/bin/clawsiecats-ping-monitor-loop";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
