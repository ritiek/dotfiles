{ config, pkgs, lib, enableLEDs, ... }:

let
  ping-monitor-loop = pkgs.writeShellScriptBin "ping-monitor-loop" ''
    CLAWSIECATS="clawsiecats.lol"
    KEYBERRY="keyberry.lion-zebra.ts.net"
    RETRIES=4
    RETRY_INTERVAL=30
    SLEEP_INTERVAL=60
    LED_PID=""

    set_led() {
      kill "$LED_PID" 2>/dev/null; wait "$LED_PID" 2>/dev/null
      LED_PID=""
      case "$1" in
        solid)
          ${pkgs.libgpiod}/bin/gpioset -c gpiochip0 27=1 &
          LED_PID=$!
          ;;
        blink)
          ${pkgs.libgpiod}/bin/gpioset -t 2s,2s -c gpiochip0 27=1 &
          LED_PID=$!
          ;;
        off)
          ${pkgs.libgpiod}/bin/gpioset -c gpiochip0 27=0 &
          LED_PID=$!
          ;;
      esac
    }

    cleanup() {
      kill "$LED_PID" 2>/dev/null; wait "$LED_PID" 2>/dev/null
      ${pkgs.libgpiod}/bin/gpioset -c gpiochip0 27=0 &
      sleep 0.5
      kill $! 2>/dev/null; wait $! 2>/dev/null
      exit 0
    }
    trap cleanup EXIT INT TERM

    echo "ping monitor starting..."

    while true; do
      echo ""
      echo "=== Pinging $CLAWSIECATS ($RETRIES retries, ''${RETRY_INTERVAL}s interval) ==="

      clawsiecats_ok=false
      for attempt in $(${pkgs.coreutils}/bin/seq 1 "$RETRIES"); do
        echo "  Attempt $attempt/$RETRIES..."
        if ${pkgs.iputils}/bin/ping -c 1 -W 5 "$CLAWSIECATS" > /dev/null 2>&1; then
          echo "$CLAWSIECATS is reachable"
          clawsiecats_ok=true
          break
        fi
        echo "  No response, waiting ''${RETRY_INTERVAL}s before retry..."
        ${pkgs.coreutils}/bin/sleep "$RETRY_INTERVAL"
      done

      if [ "$clawsiecats_ok" = true ]; then
        echo ""
        echo "=== Pinging $KEYBERRY ($RETRIES retries, ''${RETRY_INTERVAL}s interval) ==="

        keyberry_ok=false
        for attempt in $(${pkgs.coreutils}/bin/seq 1 "$RETRIES"); do
          echo "  Attempt $attempt/$RETRIES..."
          if ${pkgs.iputils}/bin/ping -c 1 -W 5 "$KEYBERRY" > /dev/null 2>&1; then
            echo "$KEYBERRY is reachable"
            keyberry_ok=true
            break
          fi
          echo "  No response, waiting ''${RETRY_INTERVAL}s before retry..."
          ${pkgs.coreutils}/bin/sleep "$RETRY_INTERVAL"
        done

        if [ "$keyberry_ok" = true ]; then
          echo "Both hosts reachable, LED off"
          set_led off
        else
          echo "$KEYBERRY is unreachable, LED blink"
          set_led blink
        fi
      else
        echo "$CLAWSIECATS is unreachable, LED solid"
        set_led solid
      fi

      echo "Cycle complete, sleeping ''${SLEEP_INTERVAL}s..."
      ${pkgs.coreutils}/bin/sleep "$SLEEP_INTERVAL"
    done
  '';
in
{  systemd.user.services.ping-monitor = {
    Unit = {
      Description = "Ping monitor for personal machines";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = "${ping-monitor-loop}/bin/ping-monitor-loop";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
