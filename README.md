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
$ bash setup.sh
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

March, 2020

<img src="https://i.imgur.com/lNSb7H2.png" width="750">

November, 2022

<img src="https://i.imgur.com/K8QXOPq.png" width="750">

(click to zoom)

## Miscellaneous

### Ctrl+L clear terminal

If `^L` won't clear terminal, add line `"\C-l":'clear\n'` to `/etc/inputrc` at the end of the file to fix it.

### Kodi - some videos won't play

Try disabling/enabling hardware acceleration in `Settings -> Player -> Videos -> Allow hardware acceleration - ...`
