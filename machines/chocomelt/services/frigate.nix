{ lib, pkgs, everythingElsePath, ... }:

# Native frigate (nixpkgs module) with the RK3566 NPU detector. Started/stopped
# with the media stack (unit listed in ./nixarr.nix `units`), not at boot, to
# keep RAM free. Data stays in the old podman layout on EVERYTHING_ELSE:
# config/ (DB, model cache) and storage/ (clips, recordings, exports).
let
  dataDir = "${everythingElsePath}/frigate";
  librknnrt = pkgs.stdenv.mkDerivation {
    pname = "librknnrt";
    version = "2.3.2";
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/airockchip/rknn-toolkit2/v2.3.2/rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so";
      hash = "sha256-0x/BnIW4X2CRsr0PavnZYtUmSk5BC/tTZALskrrHOOg=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = "install -Dm755 $src $out/lib/librknnrt.so";
  };

  # Minimal stand-in for rknn-toolkit-lite2's `rknnlite.api.RKNNLite`, which
  # only ships cpython<=3.12 wheels while nixpkgs' frigate runs on python 3.13.
  # Covers just what frigate's RKNNModelRunner calls, via librknnrt's C API
  # (rknn_api.h).
  rknnlite = pkgs.writeTextDir "rknnlite/api/__init__.py" ''
    import ctypes as C

    import numpy as np

    _lib = C.CDLL("${librknnrt}/lib/librknnrt.so")
    _ctx_t = C.c_uint64  # rknn_context is uint64_t on aarch64

    _DTYPES = {
        np.dtype(np.float32): 0,
        np.dtype(np.float16): 1,
        np.dtype(np.int8): 2,
        np.dtype(np.uint8): 3,
        np.dtype(np.int16): 4,
    }
    _NHWC = 1
    _QUERY_IN_OUT_NUM, _QUERY_OUTPUT_ATTR = 0, 2


    class _InOutNum(C.Structure):
        _fields_ = [("n_input", C.c_uint32), ("n_output", C.c_uint32)]


    class _TensorAttr(C.Structure):
        _fields_ = [
            ("index", C.c_uint32),
            ("n_dims", C.c_uint32),
            ("dims", C.c_uint32 * 16),
            ("name", C.c_char * 256),
            ("n_elems", C.c_uint32),
            ("size", C.c_uint32),
            ("fmt", C.c_int),
            ("type", C.c_int),
            ("qnt_type", C.c_int),
            ("fl", C.c_int8),
            ("zp", C.c_int32),
            ("scale", C.c_float),
            ("w_stride", C.c_uint32),
            ("size_with_stride", C.c_uint32),
            ("pass_through", C.c_uint8),
            ("h_stride", C.c_uint32),
        ]


    class _Input(C.Structure):
        _fields_ = [
            ("index", C.c_uint32),
            ("buf", C.c_void_p),
            ("size", C.c_uint32),
            ("pass_through", C.c_uint8),
            ("type", C.c_int),
            ("fmt", C.c_int),
        ]


    class _Output(C.Structure):
        _fields_ = [
            ("want_float", C.c_uint8),
            ("is_prealloc", C.c_uint8),
            ("index", C.c_uint32),
            ("buf", C.c_void_p),
            ("size", C.c_uint32),
        ]


    class RKNNLite:
        NPU_CORE_AUTO = 0

        def __init__(self, verbose=False, **_):
            self._ctx = _ctx_t(0)
            self._model = None
            self._outputs = []

        def load_rknn(self, path):
            with open(path, "rb") as f:
                self._model = f.read()
            return 0

        def init_runtime(self, core_mask=0, **_):
            model = C.create_string_buffer(self._model, len(self._model))
            ret = _lib.rknn_init(C.byref(self._ctx), model, len(self._model), 0, None)
            if ret != 0:
                return ret
            # Single-core SoCs (rk3566) reject explicit masks; 0 = auto.
            if core_mask and _lib.rknn_set_core_mask(self._ctx, core_mask) != 0:
                return -1
            num = _InOutNum()
            ret = _lib.rknn_query(self._ctx, _QUERY_IN_OUT_NUM, C.byref(num), C.sizeof(num))
            if ret != 0:
                return ret
            for i in range(num.n_output):
                attr = _TensorAttr(index=i)
                ret = _lib.rknn_query(self._ctx, _QUERY_OUTPUT_ATTR, C.byref(attr), C.sizeof(attr))
                if ret != 0:
                    return ret
                self._outputs.append(tuple(attr.dims[: attr.n_dims]))
            return 0

        def inference(self, inputs, **_):
            inputs = [np.ascontiguousarray(x) for x in inputs]
            ins = (_Input * len(inputs))()
            for i, x in enumerate(inputs):
                ins[i] = _Input(i, x.ctypes.data, x.nbytes, 0, _DTYPES[x.dtype], _NHWC)
            if _lib.rknn_inputs_set(self._ctx, len(inputs), ins) != 0:
                return None
            if _lib.rknn_run(self._ctx, None) != 0:
                return None
            results = [np.empty(shape, dtype=np.float32) for shape in self._outputs]
            outs = (_Output * len(results))()
            for i, r in enumerate(results):
                outs[i] = _Output(1, 1, i, r.ctypes.data, r.nbytes)
            ret = _lib.rknn_outputs_get(self._ctx, len(results), outs, None)
            _lib.rknn_outputs_release(self._ctx, len(results), outs)
            return results if ret == 0 else None

        def release(self):
            if self._ctx.value:
                _lib.rknn_destroy(self._ctx)
                self._ctx = _ctx_t(0)
  '';

  # Shipped in the source tree but not installed by the package.
  labelmap = pkgs.runCommand "coco-80.txt" { } ''
    cp ${pkgs.frigate.src}/docker/main/rootfs/labelmap/coco-80.txt $out
  '';
in
{
  # Frigate reads GPU/NPU temperatures from RK3588 zone numbers (thermal_zone5
  # and 6); on the RK3566 gpu-thermal is zone1. Look the zones up by type.
  # An overlay, not services.frigate.package: the package's pythonPath (used
  # below) points at pkgs.frigate.
  nixpkgs.overlays = [
    (final: prev: {
      frigate = prev.frigate.overridePythonAttrs (old: {
        patches = old.patches ++ [ ./frigate-thermal-zone-by-type.patch ];
      });
    })
  ];

  services.frigate = {
    enable = true;
    hostname = "chocomelt.lion-zebra.ts.net";
    settings = {
      database.path = "${dataDir}/config/frigate.db";
      mqtt.enabled = false;
      # Decode and downscale the MJPEG streams on the RK3566's MPP/RGA instead
      # of the CPU: about a third of the CPU for the XIAO's 1600x1200 stream.
      ffmpeg = {
        path = (import ./rockchip-ffmpeg.nix pkgs).bin;
        hwaccel_args = "preset-rkmpp";
      };
      # The -rk3566 .rknn model is downloaded into model_cache on first start.
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
        labelmap_path = "${labelmap}";
      };
      record.enabled = false;
      snapshots.enabled = false;
      objects.track = [ "person" "car" "bicycle" "motorcycle" "dog" ];
      # Test camera (a public feed), off to save memory. Uncomment to test
      # detection without the XIAO.
      # cameras.pavilion = {
      #   ffmpeg.inputs = [{
      #     path = "http://64.191.148.57/mjpg/video.mjpg";
      #     input_args = "preset-http-mjpeg-generic";
      #     roles = [ "detect" ];
      #   }];
      #   detect = {
      #     enabled = true;
      #     width = 800;
      #     height = 450;
      #     # The public feed only delivers ~3 fps from here.
      #     fps = 5;
      #   };
      # };
      # Seeed XIAO ESP32S3 Sense (OV3660) on custom Tasmota: 1600x1200 MJPEG
      # at ~8 fps on its port-81 stream server.
      cameras.xiao = {
        ffmpeg.inputs = [{
          path = "http://192.168.2.15:81/stream";
          input_args = "preset-http-mjpeg-generic";
          roles = [ "detect" ];
        }];
        detect = {
          enabled = true;
          width = 800;
          height = 600;
          fps = 5;
        };
      };
    };
  };

  # The package hardcodes /var/lib/frigate as its media dir, and nginx serves
  # clips/recordings from there too, so bind it on the host (not BindPaths).
  # Fails while EVERYTHING_ELSE is unmounted (its empty mountpoint is +i).
  systemd.mounts = [{
    what = "${dataDir}/storage";
    where = "/var/lib/frigate";
    type = "none";
    options = "bind";
    unitConfig.StopWhenUnneeded = true;
  }];

  # The podman container ran as root; native frigate runs as `frigate`.
  # Applied by `mediaserver-mount` re-running systemd-tmpfiles.
  systemd.tmpfiles.settings."frigate-radrubble"."${dataDir}".Z = {
    user = "frigate";
    group = "frigate";
  };

  systemd.services.frigate = {
    environment.PYTHONPATH = lib.mkForce "${pkgs.frigate.pythonPath}:${rknnlite}";
    unitConfig.RequiresMountsFor = [ "/var/lib/frigate" ];
    serviceConfig = {
      BindPaths = [ "${dataDir}/config/model_cache:/var/cache/frigate/model_cache" ];
      # database.path lives here; ProtectSystem=strict makes it read-only
      # otherwise and the camera processor dies on its first DB write.
      ReadWritePaths = [ "${dataDir}/config" ];
      # librknnrt opens the NPU via /dev/dri/card1 (root:video 0660).
      SupplementaryGroups = [ "video" ];
      # Frigate's watchdog reads /proc/1 before exiting on a stalled
      # detector; "invisible" makes that crash instead of restarting.
      ProtectProc = lib.mkForce "default";
      # Stats poll rknpu/load (NPU usage) and rkrga/load (shown as GPU usage,
      # because of preset-rkmpp) every ~15s. debugfs root is 0700 but both
      # dirs are world-readable, so expose just those. ProtectKernelTunables
      # would mount the real debugfs back over the tmpfs below and turn the
      # reads into permission-error tracebacks; /sys stays root-only for
      # writes anyway.
      ProtectKernelTunables = lib.mkForce false;
      TemporaryFileSystem = lib.mkForce [
        "/dev/shm:mode=1777,nosuid,nodev" # from the upstream module
        "/sys/kernel/debug:ro"
      ];
      BindReadOnlyPaths = [ "/sys/kernel/debug/rknpu" "/sys/kernel/debug/rkrga" ];
      Restart = lib.mkForce "always";
      # 2GB board: an OOM-kill beats thrashing into a watchdog reboot.
      MemoryMax = "1200M";
    };
  };

  # nginx vhost with frigate's login (admin password is printed in
  # `journalctl -u frigate` on first start).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}
