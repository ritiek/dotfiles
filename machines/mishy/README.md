# mishy

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

## Screenshots

March, 2020

<img src="https://i.imgur.com/lNSb7H2.png" width="750">

November, 2022

<img src="https://i.imgur.com/K8QXOPq.png" width="750">

July, 2024

<img src="https://i.imgur.com/rI8Wnka.png" width="750">
<img src="https://i.imgur.com/s6ivguO.png" width="750">
