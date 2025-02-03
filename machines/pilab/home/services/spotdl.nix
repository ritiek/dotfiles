{ config, pkgs, lib, inputs, ... }:
let
  spotdl-sync = (pkgs.writeShellScriptBin "spotdl-sync" ''
    for directory in */; do
      cd "$directory"
      ${pkgs.spotdl}/bin/spotdl sync *.spotdl
      if [ $? -ne 0 ]; then
        ${pkgs.coreutils}/bin/echo "Failed to sync *.spotdl."
        exit $?
      fi
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

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    source ~/.config/sops-nix/secrets/uptime-kuma.env

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/jk2k8QAm9h?status=$STATUS&msg=$SERVICE_RESULT&ping="

    if [ $? -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma succeeded."
    else
      ${pkgs.coreutils}/bin/echo "ping-uptime-kuma failed."
      exit $?
    fi
  '');
in
{
  sops.secrets."uptime-kuma.env" = {};

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
