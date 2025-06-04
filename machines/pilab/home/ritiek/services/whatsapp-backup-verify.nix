{ config, pkgs, lib, inputs, ... }:

let
  whatsapp-chat-exporter-dev = (pkgs.python3Packages.buildPythonPackage {
    # $ whatsapp-chat-exporter \
    #   --android \
    #   --key $(cat key.txt) \
    #   --backup msgstore.db.crypt15 \
    #   --include "0000000000" \
    #   --output /tmp
    pname = "whatsapp-chat-exporter";
    version = "dev";
    format = "pyproject";

    src = pkgs.fetchFromGitHub {
      owner = "KnugiHK";
      repo = "WhatsApp-Chat-Exporter";
      rev = "9f321384ece48e262d325b80b1fb1669cf90dae3";   # branch: dev (1st March, 2025)
      sha256 = "sha256-/ul132+qQxJBrexlArJMH0vfmPGDiXdvnhgxeue7WIA=";
    };

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      pip
      wheel
    ];

    propagatedBuildInputs = with pkgs.python3Packages; [
      jinja2
      bleach
      pycryptodome
      javaobj-py3
      vobject
    ];
  });

  whatsapp-backup-verify = (pkgs.writers.writePython3Bin "whatsapp-backup-verify" {
    libraries = with pkgs; [ whatsapp-chat-exporter-dev ]; } ''
      from Whatsapp_Chat_Exporter.android_crypt import decrypt_backup
      from Whatsapp_Chat_Exporter.utility import Crypt

      import sys
      import argparse

      parser = argparse.ArgumentParser(
          "whatsapp-backup-verify",
          description=(
            "Check if a WhatsApp's db.crypt15 is tied to a given "
            "32-bit hex key"
          )
      )
      parser.add_argument(
        "path_to_encrypted_db",
      )
      parser.add_argument(
        "path_to_hex_key",
        nargs="?",
        default="${config.sops.secrets."whatsapp.key".path}",
      )

      args = parser.parse_args()

      with open(args.path_to_encrypted_db, "rb") as fin:
          database = fin.read()

      with open(args.path_to_hex_key, "r") as fin:
          key = fin.read()

      key = bytes.fromhex(key.replace(" ", ""))

      return_code = decrypt_backup(
          database=database,
          key=key,
          crypt=Crypt.CRYPT15,
          dry_run=True,
      )

      sys.exit(return_code)
  '');

  whatsapp-backup-verify-latest-snapshot = (pkgs.writeShellScriptBin "whatsapp-backup-verify-latest-snapshot" ''
    ${whatsapp-backup-verify}/bin/whatsapp-backup-verify \
      $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."path-to-whatsapp-db.txt".path})
  '');

  ping-uptime-kuma = (pkgs.writeShellScriptBin "ping-uptime-kuma@whatsapp-backup-verify-latest-snapshot" ''
    if [ "$EXIT_STATUS" -eq 0 ]; then
      STATUS=up
    else
      STATUS=down
    fi

    # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
    # to work:
    # source $\{osConfig.sops.secrets."uptime-kuma.env".path}
    source ~/.config/sops-nix/secrets/uptime-kuma.env

    ${pkgs.curl}/bin/curl -s "$UPTIME_KUMA_INSTANCE_URL/api/push/a0DWjFa9sb?status=$STATUS&msg=$SERVICE_RESULT&ping="
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
  sops.secrets."whatsapp.key" = {};
  sops.secrets."path-to-whatsapp-db.txt" = {};
  sops.secrets."uptime-kuma.env" = {};

  home.packages = with pkgs; [
    whatsapp-chat-exporter-dev
    whatsapp-backup-verify
    whatsapp-backup-verify-latest-snapshot
    curl
    jq
  ];

  systemd.user.services.whatsapp-backup-verify-latest-snapshot = {
    Unit = {
      Description = "Check if a WhatsApp's db.crypt15 is tied to a given 32-bit hex key";
      RequiresMountsFor = [
        "/media/HOMELAB_MEDIA"
      ];
    };
    Service = {
      Type = "oneshot";
      WorkingDirectory = "/media/HOMELAB_MEDIA";
      ExecStart = "${whatsapp-backup-verify-latest-snapshot}/bin/whatsapp-backup-verify-latest-snapshot";
      ExecStopPost = "${ping-uptime-kuma}/bin/ping-uptime-kuma@whatsapp-backup-verify-latest-snapshot";
    };
  };

  systemd.user.timers.whatsapp-backup-verify-latest-snapshot = {
    Unit = {
      Description = "Periodically check if a WhatsApp's db.crypt15 is tied to a given 32-bit hex key";
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "6h";
      Unit = "whatsapp-backup-verify-latest-snapshot.service";
    };
  };
}
