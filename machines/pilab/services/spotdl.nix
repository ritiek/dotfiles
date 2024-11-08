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
in
{
  environment.systemPackages = with pkgs; [
    spotdl
    spotdl-sync
  ];

  systemd.services.spotdl-sync = {
    path = [ pkgs.spotdl ];
    unitConfig = {
      Description = "Sync Spotify playlists locally.";
      RequiresMountsFor = [
        "/media/services/spotdl"
      ];
    };
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/media/services/spotdl";
      ExecStart = "${spotdl-sync}/bin/spotdl-sync";
      ExecStop = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";
      ExecReload = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";

      # Restart = lib.mkOverride 500 "always";
      # RestartMaxDelaySec = lib.mkOverride 500 "1m";
      # RestartSec = lib.mkOverride 500 "100ms";
      # RestartSteps = lib.mkOverride 500 9;
    };
    after = [
      "network-online.target"
    ];
    requires = [
      "network-online.target"
    ];
    # wantedBy = [ "multi-user.target" ];
  };

  systemd.timers.spotdl-sync = {
    unitConfig = {
      Description = "Run sync Spotify playlists service periodically.";
    };
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "6h";
      Unit = "spotdl-sync.service";
    };
    # wantedBy = [ "timers.target" ];
  };
}
