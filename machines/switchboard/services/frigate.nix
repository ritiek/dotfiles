{ config, ... }:

# Frigate on the CPU only. This board is the A527 variant of the Cubie A5E:
# the NPU node probes but reads back GC0 (fused off; only the T527 has it),
# mainline has no video engine (cedrus) driver for the A523 family, and
# panfrost has no video decode. So:
#   - detect: the 640x480 H.264 substream, decoded on the CPU at 5 fps,
#     with the default SSDLite MobileDet tflite model on the CPU detector.
#   - live view: go2rtc restreams the 2304x1296 HEVC main stream untouched
#     (browser needs HEVC support, e.g. Chrome/Edge/Safari). Nothing records.
let
  # The camera URL (with credentials) only lives in go2rtc's environment.
  streams = {
    imou_1 = "\${IMOU_1_RTSP}&subtype=0";
    imou_1_sub = "\${IMOU_1_RTSP}&subtype=1";
  };
in
{
  sops.secrets."imou-1.rtsp" = { };
  sops.templates."go2rtc.env" = {
    content = "IMOU_1_RTSP=${config.sops.placeholder."imou-1.rtsp"}";
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
      # Frigate doesn't run go2rtc here, but the UI only offers MSE/WebRTC live
      # view for streams it sees listed in its own config.
      go2rtc.streams = streams;
      # Default SSDLite MobileDet, benchmarked here: 109 ms at 3 threads, 53 ms
      # at 8. SSD MobileNet v2 does 34 ms but is noticeably less accurate.
      detectors.cpu = {
        type = "cpu";
        num_threads = 8;
      };
      # One camera: birdseye would only add an always-on mpeg1 encoder.
      birdseye.enabled = false;
      record.enabled = false;
      snapshots = {
        enabled = true;
        retain.default = 7;
      };
      objects.track = [ "person" "car" "bicycle" "motorcycle" "dog" ];
      cameras.imou_1 = {
        ffmpeg.inputs = [{
          path = "rtsp://127.0.0.1:8554/imou_1_sub";
          input_args = "preset-rtsp-restream";
          roles = [ "detect" ];
        }];
        detect = {
          enabled = true;
          width = 640;
          height = 480;
          fps = 5;
        };
      };
    };
  };

  # nginx vhost with frigate's login (admin password is printed in
  # `journalctl -u frigate` on first start).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}
