{ config, pkgs, lib, inputs, ... }:
let
  spotdl-sync = (pkgs.writeShellScriptBin "spotdl-sync" ''
    for directory in */; do
      cd "$directory"
      ${pkgs.spotdl}/bin/spotdl sync *.spotdl
      cd ..
      echo
    done
  '');

  ping-uptime-kuma = (pkgs.writeShellScriptBin "ping-uptime-kuma@spotdl-sync" ''
    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi
    ${pkgs.curl}/bin/curl -s "http://127.0.0.1:3001/api/push/jk2k8QAm9h?status=$STATUS&msg=$SERVICE_RESULT&ping="
    exit 0
  '');
in
{
  home.packages = with pkgs; [
    spotdl
    spotdl-sync
    curl
  ];

  systemd.user.services.spotdl-sync = {
    Unit = {
      Description = "Sync Spotify playlists locally.";
      RequiresMountsFor = [
        "/media/HOMELAB_MEDIA/services/spotdl"
      ];
      # After = "network-online.target";
      # Requires = [
      #   "network-online.target"
      # ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "/media/HOMELAB_MEDIA/services/spotdl";
      ExecStart = "${spotdl-sync}/bin/spotdl-sync";
      # ExecStop = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";
      # ExecReload = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";
      ExecStopPost = "${ping-uptime-kuma}/bin/ping-uptime-kuma@spotdl-sync";

      # Restart = lib.mkOverride 500 "always";
      # RestartMaxDelaySec = lib.mkOverride 500 "1m";
      # RestartSec = lib.mkOverride 500 "100ms";
      # RestartSteps = lib.mkOverride 500 9;
    };
    # wantedBy = [ "multi-user.target" ];
  };

  systemd.user.timers.spotdl-sync = {
    Unit = {
      Description = "Run sync Spotify playlists service periodically.";
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "6h";
      Unit = "spotdl-sync.service";
    };
    # Install = {
    #   WantedBy = [ "timers.target" ];
    # };
  };
}
