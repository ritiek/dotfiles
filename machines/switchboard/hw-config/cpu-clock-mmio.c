// Minimal 32-bit MMIO reader used by cubie-a5e-cpuclk (see ./cpu-clock.nix).
//
// Why this exists rather than `dd if=/dev/mem`:
//
// /dev/mem offers two access paths and only one of them is correct for MMIO
// on arm64. The read()/write() path (drivers/char/mem.c:read_mem) goes through
// xlate_dev_mem_ptr(), which on architectures without a special override is a
// plain __va() - a *linear-map* translation that is only meaningful for real
// RAM. The mmap() path (mmap_mem) instead runs phys_mem_access_prot(), which
// returns pgprot_noncached() for any pfn that is not RAM, and then maps it
// with remap_pfn_range(). Device registers must be accessed uncached, so mmap
// is the only path guaranteed to give correct values here.
//
// Access is permitted despite CONFIG_STRICT_DEVMEM=y (which nixpkgs sets by
// default, pkgs/os-specific/linux/kernel/common-config.nix). arm64 selects
// GENERIC_LIB_DEVMEM_IS_ALLOWED, whose implementation in lib/devmem_is_allowed.c
// is:
//
//     if (iomem_is_exclusive(PFN_PHYS(pfn))) return 0;
//     if (!page_is_ram(pfn))                 return 1;
//     return 0;
//
// i.e. non-RAM MMIO is allowed as long as no driver has claimed the region.
// Mainline has no driver for the A523 CPC block, so it is unclaimed and
// readable. If a CPU-PLL clock driver ever lands upstream, this tool will
// start failing with EPERM - which would be good news, and the right response
// is to delete it and read the clock from /sys/kernel/debug/clk instead.
//
// Read-only by construction: the mapping is PROT_READ.

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	if (argc < 2) {
		fprintf(stderr, "usage: %s <phys-addr> [phys-addr ...]\n", argv[0]);
		return 2;
	}

	int fd = open("/dev/mem", O_RDONLY | O_SYNC);
	if (fd < 0) {
		fprintf(stderr, "open /dev/mem: %s\n", strerror(errno));
		return 1;
	}

	long pagesize = sysconf(_SC_PAGESIZE);
	int rc = 0;

	for (int i = 1; i < argc; i++) {
		char *end = NULL;
		errno = 0;
		uintmax_t addr = strtoumax(argv[i], &end, 0);
		if (errno || !end || *end || (addr & 3)) {
			fprintf(stderr, "bad address %s (must be 4-byte aligned)\n", argv[i]);
			rc = 2;
			continue;
		}

		off_t base = (off_t)(addr & ~(uintmax_t)(pagesize - 1));
		size_t off = (size_t)(addr - (uintmax_t)base);

		volatile uint8_t *map = mmap(NULL, (size_t)pagesize, PROT_READ,
					     MAP_SHARED, fd, base);
		if (map == MAP_FAILED) {
			fprintf(stderr, "mmap 0x%" PRIxMAX ": %s\n", addr, strerror(errno));
			rc = 1;
			continue;
		}

		uint32_t val = *(volatile uint32_t *)(map + off);
		munmap((void *)map, (size_t)pagesize);

		printf("0x%08" PRIx32 "\n", val);
	}

	close(fd);
	return rc;
}
