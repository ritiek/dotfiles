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
    description = "Router NIC tuning (RPS, IRQ affinity, offloads)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-networkd.service" ];
    path = with pkgs; [ ethtool gawk coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u

      for dev in end1 end0; do
        [ -d "/sys/class/net/$dev" ] || continue

        # Both MACs are single-queue and every interrupt lands on CPU0
        # (measured: 4M+ interrupts on end0, all CPU0), so RX softirq work has
        # to be spread by hand.
        #
        # Mask f = CPUs 0-3. The A527 is 4x A55 @1.8GHz + 4x A55 @1.4GHz and
        # steering packets onto the little cluster hurts; VERIFY that the big
        # cluster really is 0-3 on this SoC before trusting this.
        #
        # RPS adds IPIs and can be a net loss at low packet rates. Worth
        # benchmarking with and without.
        for q in /sys/class/net/"$dev"/queues/rx-*/rps_cpus; do
          [ -e "$q" ] || continue
          echo f > "$q" || true
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

      # Put the two NIC interrupts on different cores.
      cpu=0
      for dev in end1 end0; do
        irq=$(awk -v d="$dev" '$NF == d { sub(":", "", $1); print $1; exit }' /proc/interrupts)
        [ -n "''${irq:-}" ] || continue
        [ -e "/proc/irq/$irq/smp_affinity" ] || continue
        printf '%x\n' $((1 << cpu)) > "/proc/irq/$irq/smp_affinity" || true
        cpu=$((cpu + 1))
      done
    '';
  };
}
