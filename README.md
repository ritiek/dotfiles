# dotfiles

Mah dotfiles, for NixOS, as well as for Debian/Arch based distros maintained using
[chezmoi](https://www.chezmoi.io/).

I previously maintained these manually in the [legacy](https://github.com/ritiek/dotfiles/tree/legacy) branch.

## Installation

### NixOS

```sh
$ sudo mv /etc/nixos{,.bak}
$ sudo git clone git@github.com:ritiek/dotfiles /etc/nixos
```

Update machine specific values in `hardware-configuration.nix` and rebuild config.

```sh
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

