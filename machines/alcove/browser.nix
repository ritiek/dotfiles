# GPU-accelerated Chromium on the headless Cubie A7S. There is no display
# (the BSP DRM/KMS stack is off, see linux-defconfig-fragment.config), so a
# headless sway renders on the PowerVR render node and wayvnc serves it on
# localhost:
#   ssh -L 5900:localhost:5900 alcove   # then point a VNC client at localhost:5900
#   chromium-gpu https://webglsamples.org/aquarium/aquarium.html
# chrome://gpu should list Compositing/Rasterization/WebGL as hardware.
#
# Only Chromium on native Wayland gets full acceleration: the vendor libEGL
# (accel.nix) is GLES-only and has no Wayland client platform, so ANGLE's
# gles-egl backend works but Firefox (wants desktop GL) and Chromium on X11
# (no EGL configs for X11 windows) fall back to software compositing.
{ lib, pkgs, ... }:

let
  # The vendor libEGL is not glvnd, so it has to shadow nixpkgs' libEGL.
  gpuEnv = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
  };
  runtimeDir = "/run/sway-headless";

  # pvr has no GEM PRIME import, so wlroots' drmPrimeFDToHandle() sanity
  # check rejects every client dmabuf (EGL imports them fine). Skip it.
  wlroots = pkgs.wlroots_0_20.overrideAttrs (o: {
    postPatch = (o.postPatch or "") + ''
      substituteInPlace types/wlr_linux_dmabuf_v1.c \
        --replace-fail 'if (linux_dmabuf->main_device_fd < 0) {' 'if (1) {'
    '';
  });
  sway = pkgs.sway-unwrapped.override { wlroots_0_20 = wlroots; };

  swayConfig = pkgs.writeText "sway-headless.conf" ''
    output HEADLESS-1 resolution 1920x1080
    xwayland disable
    exec ${pkgs.wayvnc}/bin/wayvnc 127.0.0.1 5900
  '';

  chromium-gpu = pkgs.writeShellScriptBin "chromium-gpu" ''
    ${lib.toShellVars gpuEnv}
    export LD_LIBRARY_PATH LIBGL_DRIVERS_PATH
    export XDG_RUNTIME_DIR=${runtimeDir} WAYLAND_DISPLAY=wayland-1
    exec ${pkgs.chromium}/bin/chromium --ozone-platform=wayland \
      --use-gl=angle --use-angle=gles-egl --ignore-gpu-blocklist "$@"
  '';
in
{
  systemd.services.sway-headless = {
    description = "Headless sway on the GPU, VNC on 127.0.0.1:5900";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.bash ]; # sway runs `exec` lines via execlp("sh")
    environment = gpuEnv // {
      XDG_RUNTIME_DIR = runtimeDir;
      WLR_BACKENDS = "headless";
      WLR_RENDERER = "gles2";
      WLR_RENDER_DRM_DEVICE = "/dev/dri/renderD128";
      # The vendor EGL marks every dmabuf modifier external-only, which leaves
      # wlroots with no render formats at all; implicit modifiers work.
      WLR_EGL_NO_MODIFIERS = "1";
    };
    serviceConfig = {
      User = "ritiek";
      RuntimeDirectory = "sway-headless";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${sway}/bin/sway -c ${swayConfig}";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = [ chromium-gpu ];
}
