{ pkgs, ... }:
{
  # None of these were installed, which blocked several pre-flight checks.
  environment.systemPackages = with pkgs; [
    ethtool
    iw
    tcpdump
    conntrack-tools
  ];

  boot.kernel.sysctl = {
    "net.core.netdev_max_backlog" = 4096;
    "net.core.netdev_budget" = 600;
  };

  systemd.services.router-nic-tuning = {
    description = "Router NIC tuning (RPS, offloads)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-networkd.service" ];
    path = with pkgs; [ ethtool coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u

      for dev in end1 end0; do
        [ -d "/sys/class/net/$dev" ] || continue

        # Both MACs are single-queue and every interrupt lands on CPU0, so
        # RPS spreads the RX softirq work. Mask fe = CPUs 1-7, i.e. every core
        # except the one taking the interrupts -- what OpenWrt's default
        # packet steering does, and the best combination measured on this
        # board (see lan.nix): ~930 Mbit/s both ways with LAN on end1.
        #
        # Note CPUs 0-3 are the LITTLE cluster (1.4 GHz) and 4-7 the big one
        # (1.8 GHz) -- cpufreq policy0 vs policy4. Pinning the NIC interrupts
        # and RPS to the big cores was measured too and did not beat this.
        for q in /sys/class/net/"$dev"/queues/rx-*/rps_cpus; do
          [ -e "$q" ] || continue
          echo fe > "$q" || true
        done

        # dwmac-sun8i has a documented regression (Armbian, kernel 6.12.58 on
        # H6) where rx/tx checksumming, scatter-gather, GSO and GRO all come
        # up disabled and transmit drops to roughly a tenth. GRO matters most
        # here: neither MAC has TSO/LRO, so coalescing in software before the
        # netfilter path is what keeps per-packet cost down.
        #
        # Applied one at a time on purpose: `ethtool -K` is atomic over its
        # whole argument list, so a single unsupported feature makes it reject
        # the lot -- which would silently skip GRO, the one that matters most.
        # Neither MAC advertises TSO/LRO, so failures here are expected.
        for feat in rx tx sg gro gso; do
          ethtool -K "$dev" "$feat" on || true
        done
      done
    '';
  };
}
