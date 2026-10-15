{ inputs, lib, pkgs, ... }:

{
  imports = [
    ./../zerostash/hw-config.nix
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    # Using this flake input, for some reason haves the kernel compile from source
    # which takes a loong time and isn't practical.
    # inputs.raspberry-pi-nix.nixosModules.raspberry-pi { raspberry-pi-nix.board = "bcm2711"; }
    inputs.pi400kb-nix.nixosModules.pi400kb
  ];

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelModules = [
    "libcomposite"
    "cma=2048M"
    "i2c-dev"
    "spi-dev"
  ];

  hardware = {
    raspberry-pi."4".fkms-3d = {
      enable = true;
      cma = 2048;
    };
    graphics.enable = true;
    # nixos-hardware dropped raspberry-pi."4".dwc2 in favour of a config.txt overlay,
    # which needs useGenerationDeviceTree = false and would drop the fkms-3d overlays.
    # This is the overlay the old option generated (USB OTG gadget for pi400kb).
    deviceTree.overlays = [{
      name = "dwc2-overlay";
      dtsText = ''
        /dts-v1/;
        /plugin/;

        / {
          compatible = "brcm,bcm2711";

          fragment@0 {
            target = <&usb>;
            #address-cells = <0x01>;
            #size-cells = <0x01>;

            __overlay__ {
              compatible = "brcm,bcm2835-usb";
              dr_mode = "otg";
              g-np-tx-fifo-size = <0x20>;
              g-rx-fifo-size = <0x22e>;
              g-tx-fifo-size = <0x200 0x200 0x200 0x200 0x200 0x100 0x100>;
              status = "okay";
              phandle = <0x01>;
            };
          };
        };
      '';
    }];
  };
}
