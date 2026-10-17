{ config, lib, pkgs, modulesPath, inputs, ... }:

let
  noZFS = {
    inputs.nixpkgs.overlays = [
      (final: super: {
        zfs = super.zfs.overrideAttrs (_: { meta.platforms = [ ]; });
      })
    ];
  };
in
{
  imports = [
    inputs.rockchip.nixosModules.sdImageRockchip
    inputs.rockchip.nixosModules.noZFS
    ./aic8800.nix
    ./boot-test.nix
    ./../../modules/radxa-zero3
  ];

  # The shared Zero 3 DT enables the 3E's ethernet; the 3W has none.
  hardware.deviceTree.overlays = [{
    name = "rk3566-zero3w-no-gmac";
    dtsText = ''
      /dts-v1/;
      /plugin/;
      / { compatible = "rockchip,rk3566"; };
      &gmac1 { status = "disabled"; };
    '';
  } {
    # Waveshare 2.13inch Touch e-Paper HAT: panel on SPI3 M1 (/dev/spidev3.0,
    # from radxa-overlays rk3568-spi3-m1-cs0-spidev). Header pins 3/5 are
    # I2C3 M0, but i2c3 is muxed to M1 for the on-board fusb302 (USB-C), so
    # the GT1151 touch (addr 0x14) gets a bit-banged bus on those pins instead,
    # pinned to /dev/i2c-7. GPIO1_A0 = SDA, GPIO1_A1 = SCL; 6 = open drain.
    name = "rk3566-zero3w-epaper";
    dtsText = ''
      /dts-v1/;
      /plugin/;
      / { compatible = "rockchip,rk3566"; };
      &spi3 {
        status = "okay";
        #address-cells = <1>;
        #size-cells = <0>;
        pinctrl-names = "default", "high_speed";
        pinctrl-0 = <&spi3m1_cs0 &spi3m1_pins>;
        pinctrl-1 = <&spi3m1_cs0 &spi3m1_pins_hs>;
        max-freq = <50000000>;
        spidev@0 {
          compatible = "rockchip,spidev";
          status = "okay";
          reg = <0>;
          spi-max-frequency = <50000000>;
        };
      };
      &pinctrl {
        epd {
          epd_i2c_pins: epd-i2c-pins {
            rockchip,pins = <1 0 0 &pcfg_pull_up>, <1 1 0 &pcfg_pull_up>;
          };
        };
      };
      &{/} {
        epd_i2c: i2c-epd {
          compatible = "i2c-gpio";
          pinctrl-names = "default";
          pinctrl-0 = <&epd_i2c_pins>;
          sda-gpios = <&gpio1 0 6>;
          scl-gpios = <&gpio1 1 6>;
          #address-cells = <1>;
          #size-cells = <0>;
        };
      };
      &{/aliases} { i2c7 = "/i2c-epd"; };
    '';
  }];

  boot.supportedFilesystems = [ "ntfs" ];
  boot.kernelModules = [ "g_ether" ];

  # USB gadget ethernet - allows SSH over USB-C on first boot
  # Connect to 10.0.0.2 from host (configure host side as 10.0.0.1/24)
  networking.interfaces.usb0.ipv4.addresses = [{
    address = "10.0.0.2";
    prefixLength = 24;
  }];

  # pkgs.armbian-firmware is non-free.
  # nixpkgs.config.allowUnfree = true;
  # hardware.firmware = with pkgs; [ armbian-firmware linux-firmware ];

  # boot.kernelPackages = inputs.rockchip.legacyPackages."aarch64-linux".kernel_linux_latest_rockchip_unstable;
  # The aic8800 driver registers its own permissive custom regulatory rules
  # ("USING PERMISSIVE CUSTOM REGULATORY RULES" in dmesg) and ignores the kernel
  # regdom, so 5GHz is never gated by cfg80211 regdom. Shipping the regulatory DB
  # is harmless and cheap; the kernel regdom hint does nothing here but is kept
  # for documentation. (regdom is NOT the cause of the cold-boot WiFi flakiness.)
  hardware.wirelessRegulatoryDatabase = true;
  boot.kernelParams = [ "cfg80211.ieee80211_regdom=IN" ];

  # Cold-boot WiFi race: the aic8800 SDIO firmware is still settling when
  # wpa_supplicant begins associating. Early attempts fail locally with
  # "CTRL-EVENT-ASSOC-REJECT bssid=00:00:00:00:00:00 status_code=1" on BOTH
  # bands, and wpa_supplicant then gets stuck in a TEMP-DISABLED retry loop while
  # the unit stays active(running) — so systemd Restart= never fires and wlan0
  # is left with only a 169.254.x link-local address. A simple
  # `systemctl restart wpa_supplicant` once the firmware has settled recovers
  # immediately. This watchdog does exactly that: after a grace period it checks
  # for a real (non-link-local) IPv4 on wlan0 and restarts wpa_supplicant until
  # one appears.
  systemd.services.wifi-watchdog = {
    description = "Restart wpa_supplicant until wlan0 gets a real IP (aic8800 cold-boot race)";
    after = [ "wpa_supplicant.service" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 pkgs.systemd pkgs.gnugrep pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      # Give a healthy boot time to associate + DHCP without any interference.
      sleep 30
      for i in $(seq 1 6); do
        ip=$(ip -4 -o addr show wlan0 2>/dev/null | grep -v '169\.254\.' | grep -oP 'inet \K[0-9.]+' | head -1)
        if [ -n "$ip" ]; then
          echo "wlan0 has real IP $ip (attempt $i) - WiFi up"
          exit 0
        fi
        echo "wlan0 has no real IP (attempt $i) - restarting wpa_supplicant"
        systemctl restart wpa_supplicant.service || true
        sleep 20
      done
      echo "wifi-watchdog: gave up after retries (wlan0 still has no real IP)"
      exit 0
    '';
  };

  # btrfs root: U-Boot reads kernel/initrd from /boot on the root partition
  # via extlinux, and its defconfig only enables ext2/ext4/fat.
  rockchip.uBoot = pkgs.ubootRadxaZero3W.overrideAttrs (old: {
    # Rockchip's BL31 (as Armbian uses): the vendor kernel needs its SCMI/SIP
    # services, mainline TF-A hangs it. Mainline kernels boot fine on it too.
    # Not auto-flashed: dd u-boot-rockchip.bin to the SD card at byte 32768.
    env = old.env // { BL31 = pkgs.rkbin.BL31_RK3568; };
    extraConfig = (old.extraConfig or "") + ''
      CONFIG_FS_BTRFS=y
      CONFIG_CMD_BTRFS=y
    '';
  });

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
