{ pkgs, config, ... }:
{
  # The login unit is a Type=oneshot with RemainAfterExit=true that snapshots
  # the key via LoadCredential at start, so it never re-reads a rotated key on
  # its own.
  sops.secrets."netbird.setupkey" = {
    owner = config.services.netbird.clients.birdnet.user.name;
    group = config.services.netbird.clients.birdnet.user.group;
    restartUnits = [ "${config.services.netbird.clients.birdnet.service.name}-login.service" ];
  };

  # systemd.tmpfiles.rules = [
  #   "d /var/lib/netbird-birdnet/.config 0700 ${config.services.netbird.clients.birdnet.user.name} ${config.services.netbird.clients.birdnet.user.group} -"
  # ];

  services.netbird = {
    enable = true;
    ui.enable = config.hardware.graphics.enable;
    clients.birdnet = {
      # user = {
      #   name = "root";
      #   group = "root";
      # };
      login = {
        enable = true;
        setupKeyFile = config.sops.secrets."netbird.setupkey".path;
        systemdDependencies = [ "run-secrets.d.mount" ];
      };
      openFirewall = true;
      openInternalFirewall = true;
      port = 51840;
      # Use NetBird's upstream default interface name ("wt0") instead of the
      # derived "nb-birdnet". Tailscale hardcodes an exclusion for interfaces
      # literally named "wt0" (see tailscale.com/net/netmon/state.go,
      # isProblematicInterface) to avoid offering NetBird's overlay address as
      # a magicsock endpoint candidate. With the derived name, Tailscale would
      # sometimes pick the NetBird tunnel as a "direct" path, causing
      # WireGuard-over-WireGuard double encapsulation and severe throughput
      # collapse under load (fine at low-rate ping, but iperf3 would show
      # near-zero throughput bursts and heavy retransmits).
      interface = "wt0";
    };
  };
}
