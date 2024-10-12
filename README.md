# dotfiles

[![machines](https://img.shields.io/github/actions/workflow/status/ritiek/dotfiles/machines.yml?label=machines&color=027148)](https://github.com/ritiek/dotfiles/actions/workflows/machines.yml)
[![generators](https://img.shields.io/github/actions/workflow/status/ritiek/dotfiles/generators.yml?label=generators&color=027148)](https://github.com/ritiek/dotfiles/actions/workflows/generators.yml)

My dotfiles. For NixOS. As well as for Debian/Arch based distros maintained using
[chezmoi](https://www.chezmoi.io/). I previously used to maintain them by writing
custom shell scripts (in the [legacy](https://github.com/ritiek/dotfiles/tree/legacy) branch).

<img src="https://i.imgur.com/kswC7UA.png" width="300">

## Machines

- [mishy](/machines/mishy)
- [clawsiecats](/machines/clawsiecats)

--------------------

### Debian/Arch based distros

It has been some time since I last tried these out. Some things might not work as is.

Install [chezmoi](https://www.chezmoi.io/install/) and run:
```sh
$ chezmoi init ritiek
$ chezmoi apply -R
```
