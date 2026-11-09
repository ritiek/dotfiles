{ config, lib, pkgs, ... }:

# Frigate on the CPU only. This board is the A527 variant of the Cubie A5E:
# the NPU node probes but reads back GC0 (fused off; only the T527 has it),
# mainline has no video engine (cedrus) driver for the A523 family, and
# panfrost has no video decode. So:
#   - detect: the 640x480 H.264 substream, decoded on the CPU at 5 fps,
#     with the default SSDLite MobileDet tflite model on the CPU detector.
#   - live view: go2rtc restreams the 2304x1296 HEVC main stream untouched
#     (browser needs HEVC support, e.g. Chrome/Edge/Safari). Nothing records.
# Alerts: events go to pilab's mosquitto under frigate-switchboard/, and
# frigate-ntfy (below) forwards person/car >= 80% to pilab's ntfy.
let
  # Same Imou model, URL and credentials on every camera; only the host differs.
  # The credentials only live in go2rtc's environment.
  cameras = [ "imou_1" "imou_2" "imou_3" "imou_4" ];
  url = cam: subtype:
    "rtsp://\${IMOU_CREDENTIALS}@${lib.replaceStrings [ "_" ] [ "-" ] cam}.pihole:554/cam/realmonitor?channel=1&subtype=${subtype}";
  streams = lib.listToAttrs (lib.concatMap (cam: [
    (lib.nameValuePair cam (url cam "0"))
    (lib.nameValuePair "${cam}_sub" (url cam "1"))
  ]) cameras);
in
{
  sops.secrets."imou.credentials" = { };
  sops.templates."go2rtc.env" = {
    content = "IMOU_CREDENTIALS=${config.sops.placeholder."imou.credentials"}";
    restartUnits = [ "go2rtc.service" ];
  };

  # API (1984) and RTSP (8554) stay firewalled; frigate and nginx use them over
  # localhost.
  services.go2rtc = {
    enable = true;
    settings.streams = streams;
  };
  systemd.services.go2rtc.serviceConfig.EnvironmentFile = config.sops.templates."go2rtc.env".path;

  services.frigate = {
    enable = true;
    hostname = "switchboard.lion-zebra.ts.net";
    settings = {
      # Own prefix so events don't mix with chocomelt's on the same broker.
      mqtt = {
        enabled = true;
        host = "pilab.lion-zebra.ts.net";
        topic_prefix = "frigate-switchboard";
        client_id = "frigate-switchboard";
      };
      # Frigate doesn't run go2rtc here, but the UI only offers MSE/WebRTC live
      # view for streams it sees listed in its own config.
      go2rtc.streams = streams;
      # Default SSDLite MobileDet, benchmarked here: 109 ms at 3 threads, 53 ms
      # at 8. SSD MobileNet v2 does 34 ms but is noticeably less accurate.
      detectors.cpu = {
        type = "cpu";
        num_threads = 8;
      };
      # birdseye would add an always-on mpeg1 encoder this box can't spare.
      birdseye.enabled = false;
      record.enabled = false;
      snapshots = {
        enabled = true;
        retain.default = 7;
      };
      objects.track = [ "person" "car" "bicycle" "motorcycle" "dog" ];
      # Only imou_1 runs detection; the others are for live view.
      cameras = lib.genAttrs cameras (cam: {
        ffmpeg.inputs = [{
          path = "rtsp://127.0.0.1:8554/${cam}_sub";
          input_args = "preset-rtsp-restream";
          roles = [ "detect" ];
        }];
        detect = {
          enabled = cam == "imou_1";
          width = 640;
          height = 480;
          fps = 5;
        };
      });
    };
  };

  # nginx vhost with frigate's login (admin password is printed in
  # `journalctl -u frigate` on first start).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

  # ntfy alerts: once per tracked object, the first time it is a person or car
  # with top_score >= 0.8, to the same ntfy topic chocomelt's alerts use.
  # chocomelt uses frigate-notify on pilab, but it isn't packaged in nixpkgs and
  # adding it there would mean redeploying (upgrading) all of pilab.
  sops.secrets."ntfy.token" = { };
  systemd.services.frigate-ntfy = {
    description = "Push Frigate person/car events to ntfy";
    after = [ "frigate.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      LoadCredential = "ntfy-token:${config.sops.secrets."ntfy.token".path}";
      Restart = "always";
      RestartSec = "10s";
    };
    script = lib.getExe (pkgs.writeShellApplication {
      name = "frigate-ntfy";
      runtimeInputs = with pkgs; [ mosquitto jq curl coreutils ];
      text = ''
        token=$(cat "$CREDENTIALS_DIRECTORY/ntfy-token")
        ui=http://switchboard.lion-zebra.ts.net
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        declare -A sent=()

        # -R skips events retained from before this service started.
        mosquitto_sub -h pilab.lion-zebra.ts.net -R -t frigate-switchboard/events \
          | jq --unbuffered -r 'select(.type != "end") | .after
              | select((.label == "person" or .label == "car") and .top_score >= 0.8)
              | [.id, .label, .camera, (.top_score * 100 | floor)] | @tsv' \
          | while IFS=$'\t' read -r id label camera score; do
              [[ -n ''${sent[$id]:-} ]] && continue
              if (( ''${#sent[@]} > 1000 )); then sent=(); fi
              sent[$id]=1
              args=(
                -H "Authorization: Bearer $token"
                -H "Title: ''${label^} on $camera"
                -H "Message: $score% confidence"
                -H "X-Click: $ui/explore?event_id=$id"
                -H "X-Actions: view, Open in Frigate, $ui/explore?event_id=$id, clear=true"
              )
              # The event snapshot may not exist yet on the first update; fall
              # back to the current frame, then to text only.
              if curl -sf -o "$tmp/snap.jpg" "http://127.0.0.1:5000/api/events/$id/snapshot.jpg" \
                || curl -sf -o "$tmp/snap.jpg" "http://127.0.0.1:5000/api/$camera/latest.jpg?height=480"; then
                args+=(-T "$tmp/snap.jpg" -H "Filename: $camera.jpg")
              else
                args+=(-d "")
              fi
              curl -sf -o /dev/null "''${args[@]}" http://pilab.lion-zebra.ts.net:8894/frigate \
                && echo "notified: $label $score% on $camera ($id)" \
                || echo "ntfy failed for $id"
            done
      '';
    });
  };
}
