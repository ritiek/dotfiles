# dotfiles

Mah dotfiles

## Installation

```bash
sudo apt install -y software-properties-common neovim tmux fonts-powerline aria2 undistract-me mpv git xclip

pip3 install powerline-status --user
pip3 install powerline-gitstatus --user

curl https://sh.rustup.rs -sSf | bash
cargo install ripgrep
cargo install fd-find
```

## Configuration

```bash
sudo curl https://raw.githubusercontent.com/ritiek/dotfiles/master/bash.bashrc -o /etc/bash.bashrc

sudo curl https://raw.githubusercontent.com/ritiek/dotfiles/master/battery.sh -o /usr/bin/battery
sudo chmod +x /usr/bin/battery

sudo curl https://raw.githubusercontent.com/ritiek/dotfiles/master/sysinit.vim -o /usr/share/nvim/sysinit.vim
sudo git clone https://github.com/VundleVim/Vundle.vim.git /usr/share/nvim/bundle/Vundle.vim

curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.bashrc -o ~/.bashrc
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.profile -o ~/.profile

curl https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf -o ~/.tmux.conf
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.tmux.conf.local -o ~/.tmux.conf.local

sudo curl https://raw.githubusercontent.com/ritiek/dotfiles/master/mpv.conf -o /etc/mpv/mpv.conf
```

```bash
# POWERLINE
# configure this env variable yourself
# find it with `pip3 show powerline-status`
export POWERLINE_INSTALLATION=$HOME/.local/lib/python3.7/site-packages/powerline

curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/config.json -o $POWERLINE_INSTALLATION/config_files/config.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek_shell_theme.json -o $POWERLINE_INSTALLATION/config_files/themes/shell/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek_colorscheme.json -o $POWERLINE_INSTALLATION/config_files/colorschemes/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ipython_config.py -o $HOME/.ipython/profile_default/ipython_config.py

unset POWERLINE_INSTALLATION
```

### NVim

```
:PluginInstall
```

### Tmux

```
$ tmux [-u]
```

## Misc

### Ctrl+L clear terminal

If `^L` won't clear terminal, add `"\C-l":'clear\n'` to `/etc/inputrc` to fix it.

### Kodi - some videos won't play

Try disabling/enabling hardware acceleration in `Settings -> Player -> Videos -> Allow hardware acceleration - ...`
