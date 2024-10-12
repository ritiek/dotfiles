# dotfiles

[![machines](https://img.shields.io/github/actions/workflow/status/ritiek/dotfiles/generators.yml?label=machines)](https://github.com/ritiek/dotfiles/actions/workflows/machines.yml)
[![generators](https://img.shields.io/github/actions/workflow/status/ritiek/dotfiles/generators.yml?label=generators)](https://github.com/ritiek/dotfiles/actions/workflows/generators.yml)

My dotfiles. For NixOS. As well as for Debian/Arch based distros maintained using
[chezmoi](https://www.chezmoi.io/). I previously used to maintain them by writing
custom shell scripts (in the [legacy](https://github.com/ritiek/dotfiles/tree/legacy) branch).

<img src="https://i.imgur.com/kswC7UA.png" width="300">

## Machines

My lovely machine configurations.

### Mishy

```sh
$ sudo mv /etc/nixos{,.bak}
$ sudo git clone https://github.com/ritiek/dotfiles /etc/nixos
```

- Update machine specific values in `environment.nix`.
- Setup Intel/AMD/Nvidia graphics in `graphics.nix`. If I want to use Intel graphics, then comment out
  `graphics.nix` entirely. If I want to be using Nvidia graphics, then leave `graphics.nix` unmodified.
- Rebuild config:
```sh
# Create a machine specific `hardware-configuration.nix`.
$ sudo nixos-generate-config

$ cd /etc/nixos/
$ nix flake update

$ sudo nixos-rebuild boot --flake '.#mishy'
$ sudo shutdown -r now
```

### Clawsiecats
A configuration optimized for limited compute availability, supposed to be deployed on VPS machines.
It hosts routing services, tailscale, some other useful stuff.

Uncomment the disko partioning configuration that should be used in [flake.nix](/flake.nix) under the
variant before deployment. Supports MBR, GPT, GPT+LUKS. I haven't gotten MBR+LUKS working yet.


#### Vultr (GPT, GPT+LUKS)

Looks to work fine on the most minimal [Vultr](https://www.vultr.com/) configuration.

| CPU   | Memory   | Disk Space |
|-------|----------|------------|
| 1 vCPU | 0.5 GB  | 10 GB SSD  |

**Deployment Steps**

1. Replace your SSH public keys in [minimal.nix](/generators/minimal.nix).

2. Build the minimal ISO:
  ```bash
  $ nix build '.#minimal-iso'
  $ ls ./result/iso/nixos.iso
  ```

3. Deploy a new machine on Vultr (any OS).

4. Update the machine settings on Vultr to boot from the generated ISO.
   Vultr takes in the ISO URL, so I'll need to host this ISO somewhere first.

5. Replace the SSH public keys in asdfasdf (todo: i need to add n reuse ssh keys from flake.nix maybe).

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

#### HostVDS (MBR)
```bash
$ ./machines/clawsiecats/anywhere.sh '.#clawsiecats' root@vps.machine.ip.address
```

#### Minimal configuration (for testing purpose):
```bash
$ ./machines/clawsiecats/anywhere.sh '.#clawsiecats-minimal' root@vps.machine.ip.address
```

### Debian/Arch based distros

Install [chezmoi](https://www.chezmoi.io/install/) and run:
```sh
$ chezmoi init ritiek
$ chezmoi apply -R
```

## Screenshots

March, 2020

<img src="https://i.imgur.com/lNSb7H2.png" width="750">

November, 2022

<img src="https://i.imgur.com/K8QXOPq.png" width="750">

July, 2024

<img src="https://i.imgur.com/rI8Wnka.png" width="750">
<img src="https://i.imgur.com/s6ivguO.png" width="750">
