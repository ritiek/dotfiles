# dotfiles

Mah dotfiles, for NixOS, as well as for Debian/Arch based distros maintained using
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

$ sudo nixos-rebuild boot --upgrade-all
$ sudo shutdown -r now
```

### Debian/Arch based distros

Install [chezmoi](https://www.chezmoi.io/install/) and run:
```sh
$ chezmoi init ritiek
$ chezmoi apply -R
```

## Screenshots

(soon!)
