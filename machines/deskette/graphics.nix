{ config, lib, pkgs, modulesPath, ... }:

{
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver  # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver  # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      # nvidia-vaapi-driver # LIBVA_DRIVER_NAME=not_sure...
      libva-vdpau-driver
      libvdpau-va-gl
    ];
    # driSupport = true;
    # driSupport32Bit = true;
    enable32Bit = true;
  };

  # Pin VA-API driver selection explicitly rather than relying on driver
  # auto-detection order — intel-vaapi-driver (i965) is older but works
  # better than intel-media-driver (iHD) for Chromium on this iGPU (Skylake
  # HD 530, gen9), per the GPU passthrough investigation (2026-07-26).
  environment.variables.LIBVA_DRIVER_NAME = "i965";
}
