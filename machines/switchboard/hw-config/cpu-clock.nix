# Read the actual A527 CPU core clock on the Radxa Cubie A5E.
#
# WHY THIS IS NEEDED
#
# Nothing in mainline Linux can tell you how fast this SoC's cores are
# actually running. Three separate gaps stack up:
#
#   1. mainline's CCU driver (drivers/clk/sunxi-ng/ccu-sun55i-a523.c) models
#      zero CPU clocks - the only CPU-adjacent symbol in the whole 54K file is
#      RST_BUS_CPUXTIMER. So `/sys/kernel/debug/clk/clk_summary` has no
#      pll-cpu node and the core clock is simply absent from the clock tree.
#   2. there is no operating-points-v2 table in the DT, so cpufreq-dt never
#      probes and `/sys/devices/system/cpu/cpu0/cpufreq` does not exist.
#   3. the CPU PLLs are not even in the CCU. On A523/A527 (sun55iw3) they live
#      in a separate, undocumented "CPC" register block at 0x08817000, which
#      no mainline driver touches and no DT node describes.
#
# The consequence is that the cores run at whatever frequency TF-A programmed
# at boot and Linux has no idea what that is. That matters twice over: it is
# unknown whether we are getting the A527's full rated clock or a conservative
# firmware default, and it is the same root cause as the inert thermal
# cooling-maps (no cpufreq -> no cooling device -> the 70C/90C passive trips in
# ./patches/0005-arm64-dts-allwinner-sun55i-add-thermal-sensors.patch fire into
# nothing, leaving only the 110C critical shutdown).
#
# WHERE THE REGISTER MAP COMES FROM
#
# U-Boot v2026.04, which boots this exact board, programs these registers in
# clock_a523_set_cpu_plls(). That is the authoritative source and is what the
# decoding below mirrors:
#
#   arch/arm/include/asm/arch-sunxi/cpu_sunxi_ncat2.h
#       SUNXI_CPU_PLL_CFG_BASE  0x08817000
#   arch/arm/include/asm/arch-sunxi/clock_sun50i_h6.h
#       CPC_CPUA_PLL_CTRL 0x04   CPC_DSU_PLL_CTRL 0x08   CPC_CPUB_PLL_CTRL 0x0c
#       CPC_CPUA_CLK_REG  0x60   CPC_CPUB_CLK_REG 0x64   CPC_DSU_CLK_REG  0x6c
#       CCM_PLL1_CTRL_N(n) (((n) - 1) << 8)   <- N field holds multiplier - 1
#   arch/arm/mach-sunxi/clock_sun50i_h6.c
#       clock_set_pll1(): n = clk / 24000000  <- PLL output = 24MHz * (N + 1)
#
# WHY THIS IS A USERSPACE TOOL AND NOT A KERNEL PATCH
#
# Deliberate. Exposing these as real clocks would mean writing a new clock
# controller driver for an undocumented register block plus a new DT node, on
# the machine that is this house's router and DNS server. The payoff would be
# identical to what this reads out directly. A driver only becomes worth
# writing as a step towards actual DVFS (OPP table + wiring the CPU rail to
# the AXP717 regulator + eFuse speed binning), which is a much larger project
# and belongs upstream in mainline sunxi.
#
# So: no kernel changes, no boot risk, fully reversible.
{ pkgs, lib, config, ... }:
let
  cfg = config.hardware.cubie-a5e;

  mmioRead = pkgs.runCommandCC "cubie-a5e-mmio-read" { } ''
    mkdir -p "$out/bin"
    $CC -O2 -Wall -Wextra -std=c11 -o "$out/bin/cubie-a5e-mmio-read" ${./cpu-clock-mmio.c}
  '';

  cpuclk = pkgs.writeShellApplication {
    name = "cubie-a5e-cpuclk";
    runtimeInputs = [ mmioRead ];
    text = ''
      # Radxa Cubie A5E / Allwinner A527 (sun55iw3) CPU clock readout.
      # See cpu-clock.nix for the provenance of every constant below.

      hosc=24000000
      cpc=$(( 0x08817000 ))

      if [ ! -r /dev/mem ]; then
        echo "cubie-a5e-cpuclk: cannot read /dev/mem - run as root" >&2
        exit 1
      fi

      # One invocation, six registers, in CPC offset order.
      regs=$(cubie-a5e-mmio-read \
        $(( cpc + 0x04 )) $(( cpc + 0x08 )) $(( cpc + 0x0c )) \
        $(( cpc + 0x60 )) $(( cpc + 0x64 )) $(( cpc + 0x6c )) | tr '\n' ' ')

      # shellcheck disable=SC2086
      set -- $regs
      pll_cpua=$1; pll_dsu=$2; pll_cpub=$3
      clk_cpua=$4; clk_cpub=$5; clk_dsu=$6

      mhz() { printf '%d.%03d MHz' $(( $1 / 1000000 )) $(( ($1 % 1000000) / 1000 )); }

      # PLL output = 24MHz * (N+1) / (P+1) / (M+1).
      #
      # U-Boot only ever writes P=0 and M=0 (clock_set_pll() explicitly clears
      # GENMASK(21,16) and GENMASK(3,0) before programming N), so in practice
      # both dividers are 1 and the /(x+1) reading cannot be wrong. The raw
      # fields are printed below so an unexpected non-zero value is visible
      # rather than silently folded into the result.
      pll_rate() {
        local v=$1 n p m
        n=$(( ((v >> 8)  & 0xff) + 1 ))
        p=$(( ((v >> 16) & 0x3f) + 1 ))
        m=$((  (v        & 0x0f) + 1 ))
        echo $(( hosc * n / p / m ))
      }

      show_pll() {
        local name=$1 v=$2 rate
        rate=$(pll_rate "$v")
        printf '  %-9s = 0x%08x  en=%d lock=%d out=%d  N=%-3d P=%d M=%d  ->  %s\n' \
          "$name" "$v" \
          $(( (v >> 31) & 1 )) $(( (v >> 28) & 1 )) $(( (v >> 27) & 1 )) \
          $(( ((v >> 8) & 0xff) + 1 )) $(( (v >> 16) & 0x3f )) $(( v & 0x0f )) \
          "$(mhz "$rate")"
      }

      # Returns the core clock for a cluster given its CLK reg and its PLL rate.
      #
      # CAVEAT on the P field (bits 17:16). Unlike CPU_CLK_APB_DIV/PERI_DIV/
      # AXI_DIV, which U-Boot defines as (((n) - 1) << shift) and so are
      # unambiguously divide-by-(field+1), CPU_CLK_CTRL_P is defined as plain
      # ((p) << 16) with no -1. That leaves it undecidable from the header
      # alone whether the divisor is (P+1) or (1 << P) -- the A523 has no
      # public datasheet to settle it. It does not matter today: every
      # writer in U-Boot passes CPU_CLK_CTRL_P(0) (clock_sun50i_h6.c:149,157),
      # and both readings give a divisor of 1 when P == 0. We assume (P+1)
      # and loudly flag any non-zero P rather than silently reporting a
      # number that could be off by a factor of two.
      core_rate() {
        local clk=$1 pllrate=$2 src pdiv
        src=$(( (clk >> 24) & 0x7 ))
        pdiv=$(( ((clk >> 16) & 0x3) + 1 ))
        case "$src" in
          0) echo $(( hosc / pdiv )) ;;
          3) echo $(( pllrate / pdiv )) ;;
          *) echo 0 ;;
        esac
      }

      show_clk() {
        local name=$1 v=$2 src srcname
        src=$(( (v >> 24) & 0x7 ))
        case "$src" in
          0) srcname="HOSC-24M" ;;
          3) srcname="CPU-PLL" ;;
          *) srcname="unknown($src)" ;;
        esac
        printf '  %-9s = 0x%08x  src=%-9s P=%d  axi/%d apb/%d peri/%d\n' \
          "$name" "$v" "$srcname" \
          $(( (v >> 16) & 0x3 )) \
          $((  (v        & 0x3) + 1 )) \
          $(( ((v >> 8)  & 0x3) + 1 )) \
          $(( ((v >> 2)  & 0x3) + 1 ))
      }

      echo "Radxa Cubie A5E - Allwinner A527 (sun55iw3) CPU clock"
      echo "CPC block @ 0x08817000 (no mainline driver; read via /dev/mem)"
      echo
      echo "PLLs:"
      show_pll PLL_CPUA "$pll_cpua"
      show_pll PLL_DSU  "$pll_dsu"
      show_pll PLL_CPUB "$pll_cpub"
      echo
      echo "Clock muxes:"
      show_clk CPUA_CLK "$clk_cpua"
      show_clk CPUB_CLK "$clk_cpub"
      show_clk DSU_CLK  "$clk_dsu"
      echo
      echo "Core clocks:"
      printf '  cluster A (cpu0-3) : %s\n' "$(mhz "$(core_rate "$clk_cpua" "$(pll_rate "$pll_cpua")")")"
      printf '  cluster B (cpu4-7) : %s\n' "$(mhz "$(core_rate "$clk_cpub" "$(pll_rate "$pll_cpub")")")"
      printf '  DSU                : %s\n' "$(mhz "$(core_rate "$clk_dsu"  "$(pll_rate "$pll_dsu")")")"

      # See the CAVEAT above core_rate(): with P == 0 the divisor is 1 under
      # either possible encoding, so the numbers above are trustworthy. If any
      # P is non-zero the encoding becomes load-bearing and undetermined, so
      # say so instead of quietly printing a possibly-halved figure.
      for pair in "CPUA:$clk_cpua" "CPUB:$clk_cpub" "DSU:$clk_dsu"; do
        pname=''${pair%%:*}
        pval=''${pair#*:}
        pfield=$(( (pval >> 16) & 0x3 ))
        if (( pfield != 0 )); then
          echo
          echo "WARNING: ''${pname}_CLK has P=$pfield, not 0." >&2
          echo "  U-Boot only ever writes P=0, and the P encoding ((P+1) vs" >&2
          echo "  (1<<P)) is not determinable from the U-Boot headers. The" >&2
          echo "  core clock above assumed (P+1) and may be wrong by 2x." >&2
          echo "  Cross-check with the perf command below before trusting it." >&2
        fi
      done
      echo
      echo "Cross-check against the PMU cycle counter with:"
      echo "  perf stat -e cycles -- timeout 5 sh -c 'while :; do :; done'"
      echo "(cycles / 5s should match the cluster clock; there is no DVFS on"
      echo " this SoC, so the value is constant.)"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cpuclk
      # For the independent PMU-based cross-check printed by the tool above.
      # The PMU path is worth keeping because it measures the frequency the
      # cores actually retire instructions at, rather than what the PLL
      # registers claim they were configured to.
      pkgs.perf
    ];

    # perf needs this to count hardware events for a non-root user; 1 is the
    # kernel's own upstream default and still forbids raw tracepoint access.
    # nixpkgs otherwise leaves this at 2 (CPU events restricted to root).
    boot.kernel.sysctl."kernel.perf_event_paranoid" = lib.mkDefault 1;
  };
}
