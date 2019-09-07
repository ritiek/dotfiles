# dotfiles

Mah dotfiles

## Must-haves

<!--
Interactive one-line installer:
```console
$ curl https://raw.githubusercontent.com/ritiek/dotfiles/master/setup.sh -sSf | sh
```
If you're vary about piping random Internet through your shell (you should be), you could first
download the script, analyze it locally and then execute the script if everything looks alright:
-->
```consle
$ curl https://raw.githubusercontent.com/ritiek/dotfiles/master/setup.sh -o setup.sh
$ cat setup.sh
$ sh setup.sh
```

### NVim

```
:PluginInstall
```

### Tmux

```
$ tmux [-u]
:Prefix + I
```

## Screenshots

<img src="https://i.imgur.com/A8ME49P.png" width="500">
<img src="https://i.imgur.com/VwVd0q9.png" width="500">
(Excuse my battery percentage and CPU temperature for Linux does not have native support for my hardware)

## Miscellaneous

### Ctrl+L clear terminal

If `^L` won't clear terminal, add line `"\C-l":'clear\n'` to `/etc/inputrc` at the end of the file to fix it.

### Kodi - some videos won't play

Try disabling/enabling hardware acceleration in `Settings -> Player -> Videos -> Allow hardware acceleration - ...`
