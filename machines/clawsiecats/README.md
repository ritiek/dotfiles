# clawsiecats

A configuration optimized for limited compute availability, targeted for VPS machines.
It hosts routing services, tailscale, some other useful stuff. It has impermanence enabled.

Uncomment the disko partioning configuration that should be used in [flake.nix](/flake.nix) under the
variant before deployment. Supports MBR, GPT, GPT+LUKS. I haven't gotten MBR+LUKS working yet.


## Vultr (GPT, GPT+LUKS)

The configuration looks to work fine on the most minimal [Vultr](https://www.vultr.com/) configuration.

| CPU   | Memory   | Disk Space |
|-------|----------|------------|
| 1 vCPU | 0.5 GB  | 10 GB SSD  |

**Deployment Steps**

1. Replace my SSH public keys in [/generators/minimal.nix](/generators/minimal.nix).

2. Build the minimal ISO:
  ```bash
  $ nix build '.#minimal-iso'
  $ ls ./result/iso/nixos.iso
  ```

3. Deploy a new machine on Vultr (any OS).

4. Update the machine settings on Vultr to boot from the generated ISO.
   Vultr takes in the ISO URL, so I'll need to host this ISO somewhere first.

5. Replace the SSH public keys in [/machines/clawsiecats/minimal.nix](/machines/clawsiecats/minimal.nix).

6. Deploy the configuration using nixos-anywhere:
   ```bash
   # For GPT+LUKS
   $ ./machines/clawsiecats/anywhere.sh '.#clawsiecats-luks' root@vps.machine.ip.address --luks

   # For GPT
   $ ./machines/clawsiecats/anywhere.sh '.#clawsiecats' root@vps.machine.ip.address
   ```
   The installation succeeds hopefully.

7. Remove the ISO from Vultr machine settings and let the machine reboot.

8. (GPT+LUKS only) Decrypt the drive in dropbear:
   ```
   $ ssh vps.machine.ip.address -p 2222
   ```

9. Log in to the freshy installed NixOS:
   ```
   $ ssh vps.machine.ip.address
   ```

10. Optional: Copy my headscale backup to `/var/lib/headscale/` on the server and and reload config with `systemctl restart headscale.service`.

11. Register ACME certificates on the server with: `sudo nixos-rebuild switch --flake .#clawsiecats`.


## HostVDS (MBR)

The configuration goes tortoise after a while on the most minimal [HostVDS](https://hostvds.com/) configuration.

| CPU   | Memory   | Disk Space |
|-------|----------|------------|
| 1 vCPU | 1.0 GB  | 10 GB SSD  |

This, however, seems like HostVDS issue to me more than configuration overloading the machine.

The very next tier machine looks to work fine.

| CPU   | Memory   | Disk Space |
|-------|----------|------------|
| 1 vCPU | 2.0 GB  | 20 GB SSD  |

**Deployment Steps**

1. Replace my SSH public keys in [/generators/minimal.nix](/generators/minimal.nix).

2. Create a new instance on HostVDS and choose Debian 12 as the OS.

3. Deploy the configuration using nixos-anywhere:
   ```bash
   $ ./machines/clawsiecats/anywhere.sh '.#clawsiecats' root@vps.machine.ip.address
   ```
   The installation succeeds hopefully.

4. Let the machine reboot.

5. Log in to the freshy installed NixOS:
   ```
   $ ssh vps.machine.ip.address
   ```


## Minimal configuration (for testing purpose):

```bash
$ ./machines/clawsiecats/anywhere.sh '.#clawsiecats-minimal' root@vps.machine.ip.address
```
