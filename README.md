# dotfiles

Mah dotfiles, maintained using [chezmoi](https://www.chezmoi.io/). I previously maintained these manually
in the [legacy](https://github.com/ritiek/dotfiles/tree/legacy) branch.


## Installation

Install [chezmoi](https://www.chezmoi.io/install/) and run:
```sh
$ chezmoi init ritiek
$ chezmoi apply -R
```

## Screenshots

(soon!)


## Miscellaneous

### Ctrl+L clear terminal

If `^L` won't clear terminal, add line `"\C-l":'clear\n'` to `/etc/inputrc` at the end of the file to fix it.

### Kodi - some videos won't play

Try disabling/enabling hardware acceleration in `Settings -> Player -> Videos -> Allow hardware acceleration - ...`
