{ pkgs, config, inputs, lib, ... }:
let
  claude-hello-email-script = pkgs.writeShellScript "claude-hello-email" ''
    set -euo pipefail

    SMTP_HOST=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cc_email.smtp_host".path})
    SMTP_PORT=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cc_email.smtp_port".path})
    SMTP_USER=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cc_email.smtp_username".path})
    SMTP_PASS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cc_email.smtp_password".path})
    TO_ADDRESS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cc_email.to_address".path})
    PROXY_URL=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."cc_email.proxy_url".path})

    # Run claude non-interactively in /var/empty and capture its response.
    OUTPUT=$(cd /var/empty && /etc/profiles/per-user/ritiek/bin/claude --model haiku -p Hi 2>&1 || true)

    MAIL_FILE=$(${pkgs.coreutils}/bin/mktemp)
    trap '${pkgs.coreutils}/bin/rm -f "$MAIL_FILE"' EXIT

    {
      printf 'From: Claude Invocation <claude@clawsiecats.lol>\n'
      printf 'To: %s\n' "$TO_ADDRESS"
      printf 'Subject: Claude Says Hi\n'
      printf 'Content-Type: text/plain; charset=utf-8\n'
      printf '\n'
      printf '%s\n' "$OUTPUT"
    } > "$MAIL_FILE"

    # SMTP ports are firewall-blocked on this VPS; tunnel through pilab's
    # 3proxy HTTP CONNECT proxy (Tailscale) to reach Mailgun SMTP.
    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      --proxytunnel -x "$PROXY_URL" \
      --url "smtp://$SMTP_HOST:$SMTP_PORT" \
      --mail-from "$SMTP_USER" \
      --mail-rcpt "$TO_ADDRESS" \
      --upload-file "$MAIL_FILE" \
      --user "$SMTP_USER:$SMTP_PASS" \
      --ssl-reqd
  '';
in
{
  sops.secrets = {
    "cc_email.smtp_host" = {};
    "cc_email.smtp_port" = {};
    "cc_email.smtp_username" = {};
    "cc_email.smtp_password" = {};
    "cc_email.to_address" = {};
    "cc_email.proxy_url" = {};
  };

  systemd.user.services.claude-hello-email = {
    Unit = {
      Description = "Send Claude 'Hello' prompt response via email";
      After = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${claude-hello-email-script}";
      TimeoutStartSec = "1800";
    };
  };

  systemd.user.timers.claude-hello-email = {
    Unit = {
      Description = "Daily 09:00 IST trigger for Claude Hello Email";
    };
    Timer = {
      # 09:00 AM IST = UTC+05:30 = 03:30 UTC
      OnCalendar = "*-*-* 03:30:00 UTC";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
