# dotfiles

**(README out of date currently)**

My dotfiles. For NixOS. As well as for Debian/Arch based distros maintained using
[chezmoi](https://www.chezmoi.io/).

I previously maintained these manually in the [legacy](https://github.com/ritiek/dotfiles/tree/legacy) branch.

## Installation

### NixOS

```sh
$ sudo mv /etc/nixos{,.bak}
$ sudo git clone https://github.com/ritiek/dotfiles /etc/nixos
```

- Update machine specific values in `environment.nix`.
- Setup Intel/AMD/Nvidia graphics in `graphics.nix`. If you want to use Intel graphics, then comment out
  `graphics.nix` entirely. If you want to be using Nvidia graphics, then leave `graphics.nix` unmodified.
- Rebuild config:
```sh
# Create a machine specific `hardware-configuration.nix`.
$ sudo nixos-generate-config

$ cd /etc/nixos
$ nix flake update

$ sudo nixos-rebuild boot --flake '.#nixin' --upgrade-all --option eval-cache false
$ sudo shutdown -r now
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
