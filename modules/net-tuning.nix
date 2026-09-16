{ ... }:
{
  # Fleet-wide TCP congestion control.
  #
  # BBR is built as a module in every kernel here but is never autoloaded, so
  # without this the sysctl below silently falls back to cubic --
  # tcp_available_congestion_control only lists "reno cubic" until tcp_bbr is
  # loaded. That silent fallback is the whole reason this line exists.
  #
  # Measured on the ~212ms clawsiecats<->pilab intercontinental path, which is
  # the worst link in the fleet: 3 alternating 20s iperf3 runs gave cubic
  # 12.5 Mbit/s mean (5.4-18.5 spread) against bbr's 18.0 Mbit/s (17.6-18.7).
  # bbr won every pair and its worst run beat cubic's best. cubic is loss-based
  # and collapses on long fat pipes; bbr models bandwidth and RTT instead.
  #
  # This is sender-side only, so it costs nothing on machines that mostly
  # receive. It applies to every TCP flow the host originates -- the nginx
  # upstream hops, ssh, restic, nix copy, attic, syncthing -- but *not* to
  # QUIC/HTTP-3, whose congestion control lives in nginx userspace over UDP.
  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";

    # bbr requires a pacing qdisc; the upstream Kconfig help for TCP_CONG_BBR
    # says so outright. Without fq, bbr's pacing is not enforced and its
    # behaviour degrades.
    #
    # CAVEAT, switchboard specifically: this replaces fq_codel, so the router
    # loses CoDel's AQM for forwarded household traffic, while bbr only helps
    # flows switchboard itself originates (almost none). Applied fleet-wide by
    # explicit request. If bufferbloat shows up on the home network, this is
    # the first thing to revert -- pin switchboard back to fq_codel.
    "net.core.default_qdisc" = "fq";
  };
}
