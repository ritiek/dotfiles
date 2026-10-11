{ pkgs, everythingElsePath, ... }:

# Started/stopped with the media stack (unit listed in ./nixarr.nix `units`),
# not at boot, since all its data lives on EVERYTHING_ELSE.
let
  # storage/ holds pilab's old clips/recordings. config/ is separate so pilab's
  # ./config.yml there isn't overwritten.
  dataDir = "${everythingElsePath}/frigate";
  # Regenerated into ${dataDir}/config/config.yml on every start; UI edits don't persist.
  configFile = (pkgs.formats.yaml { }).generate "frigate.yml" {
    mqtt.enabled = false;
    # RK3566 NPU; the -rk3566 .rknn model is downloaded into model_cache on first start.
    detectors.npu = {
      type = "rknn";
      num_cores = 0;
    };
    model = {
      path = "frigate-fp16-yolov9-t";
      model_type = "yolo-generic";
      width = 320;
      height = 320;
      input_tensor = "nhwc";
      labelmap_path = "/labelmap/coco-80.txt";
    };
    record.enabled = false;
    snapshots.enabled = false;
    objects.track = [ "person" "car" "bicycle" "motorcycle" "dog" ];
    cameras.pavilion = {
      ffmpeg.inputs = [{
        path = "http://64.191.148.57/mjpg/video.mjpg";
        input_args = "preset-http-mjpeg-generic";
        roles = [ "detect" ];
      }];
      detect = {
        enabled = true;
        width = 800;
        height = 450;
        # The public feed only delivers ~3 fps from here.
        fps = 5;
      };
    };
  };
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.frigate = {
    image = "ghcr.io/blakeblackshear/frigate:0.18.0-rk";
    volumes = [
      "${dataDir}/config:/config"
      "${dataDir}/storage:/media/frigate"
      "/etc/localtime:/etc/localtime:ro"
      "/sys:/sys:ro"
    ];
    extraOptions = [
      # Host network: no netavark NAT; nixos-fw decides what is reachable.
      "--network=host"
      "--shm-size=256m"
      "--mount=type=tmpfs,target=/tmp/cache,tmpfs-size=64m"
      "--device=/dev/dri"
      "--device=/dev/dma_heap"
      "--device=/dev/rga"
      "--device=/dev/mpp_service"
      # Docker's systempaths=unconfined: the RKNN plugin reads /proc/device-tree/compatible.
      "--security-opt=unmask=ALL"
    ];
  };

  systemd.services.podman-frigate.preStart = ''
    install -D -m 0644 ${configFile} ${dataDir}/config/config.yml
  '';

  # Authenticated UI (admin password is printed in the container log on first start).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8971 ];
}
