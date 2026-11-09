# HP LaserJet P1007 (host-based, needs firmware uploaded on every power-on).
{ pkgs, ... }:

let
  # HP's official firmware from the HPLIP plugin (same URL/hash nixpkgs uses for hplipWithPlugin).
  firmware = pkgs.runCommand "hp_laserjet_p1007.fw" {
    src = pkgs.fetchurl {
      urls = [
        "https://developers.hp.com/sites/default/files/2026-05/hplip-3.26.4-plugin.run"
        "https://www.openprinting.org/download/printdriver/auxfiles/HP/plugins/hplip-3.26.4-plugin.run"
      ];
      # developers.hp.com returns 403 without a browser user agent.
      curlOptsList = [ "--user-agent" "Mozilla/5.0 Gecko/20100101 Firefox/150.0" ];
      hash = "sha256-GZ94+K9/NolNcYDpCQljziVQp17HAfikujdmWpdG/fA=";
    };
  } ''
    sh $src --noexec --target plugin
    gzip -dc plugin/hp_laserjet_p1007.fw.gz > $out
  '';
in
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.foo2zjs ];
  };

  hardware.printers = {
    ensurePrinters = [{
      name = "HP_LaserJet_P1007";
      deviceUri = "usb://HP/LaserJet%20P1007?serial=EC0HKLJ";
      model = "HP-LaserJet_P1007.ppd.gz";
      ppdOptions.PageSize = "A4";
    }];
    ensureDefaultPrinter = "HP_LaserJet_P1007";
  };

  # CUPS detaches/reattaches usblp around jobs, so only upload when the printer lacks firmware.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usbmisc", KERNEL=="lp*", ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="4817", RUN+="${pkgs.systemd}/bin/systemctl --no-block start hp-p1007-firmware@%k.service"
  '';

  systemd.services."hp-p1007-firmware@" = {
    description = "Upload firmware to HP LaserJet P1007 on /dev/usb/%i";
    serviceConfig.Type = "oneshot";
    scriptArgs = "%i";
    script = ''
      dev=/dev/usb/$1
      if ${pkgs.foo2zjs}/bin/usb_printerid "$dev" | ${pkgs.gnugrep}/bin/grep -q FWVER; then
        echo "firmware already loaded on $dev"
      else
        cat ${firmware} > "$dev"
        echo "firmware uploaded to $dev"
      fi
    '';
  };
}
