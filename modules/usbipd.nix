{ pkgs, ... }:
{
  boot.kernelModules = [ "usbip_host" ];
  environment.systemPackages = with pkgs; [
    linuxPackages.usbip
  ];
  systemd.services.usbipd = {
    enable = true;
    description = "USB-IP Daemon";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.linuxPackages.usbip}/bin/usbipd";
      # ExecStop = "${pkgs.usbip}/bin/usbip bind -b 1-1";
      # ExecStopPost = "${pkgs.usbip}/bin/usbip unbind -b 1-1";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
