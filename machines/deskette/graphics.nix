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
}
