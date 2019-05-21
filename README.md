# dotfiles

Mah dotfiles

## Must-haves

```bash
# Default to "en_US.UTF8" locale
sudo dpkg-reconfigure locales

sudo apt install -y software-properties-common \
                    neovim \
                    tmux \
                    fonts-powerline \
                    aria2 \
                    undistract-me \
                    mpv \
                    git \
                    xclip \
                    python3-pip \
                    openssh-server

pip3 install setuptools wheel --user
pip3 install powerline-status powerline-gitstatus --user
pip3 install youtube-dl --user
```

```bash
# Rust & tools
curl https://sh.rustup.rs -sSf | bash
cargo install ripgrep
cargo install fd-find
cargo install sd
cargo install bat
```

```
# Wavebox
wget -qO - https://wavebox.io/dl/client/repo/archive.key | sudo apt-key add -
echo "deb https://wavebox.io/dl/client/repo/ x86_64/" | sudo tee --append /etc/apt/sources.list.d/wavebox.list
sudo apt update
sudo apt install wavebox
# Wavebox Fonts
sudo apt install ttf-mscorefonts-installer
```

## Configuration

```bash
# My lovely machines
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.ssh/authorized_keys -o ~/.ssh/authorized_keys

# Display current battery % with `$ battery`
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/battery.sh -o ~/.local/bin/battery
chmod +x ~/.local/bin/battery

# NVim configuration
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/sysinit.vim -o ~/.local/share/nvim/sysinit.vim
git clone https://github.com/VundleVim/Vundle.vim.git ~/.local/share/nvim/bundle/Vundle.vim

# Shell configuration files
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.bashrc -o ~/.bashrc
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.profile -o ~/.profile

# Tmux configuration
curl https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf -o ~/.tmux.conf
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.tmux.conf.local -o ~/.tmux.conf.local

# Mpv configuration
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/mpv.conf -o ~/.config/mpv/mpv.conf
```

```bash
# Configure Powerline prompt

# Configure this environment variable based on your python version
# find it with `pip3 show powerline-status`
export POWERLINE_INSTALLATION=$HOME/.local/lib/python3.7/site-packages/powerline

curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/config.json -o $POWERLINE_INSTALLATION/config_files/config.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek_shell_theme.json -o $POWERLINE_INSTALLATION/config_files/themes/shell/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek_colorscheme.json -o $POWERLINE_INSTALLATION/config_files/colorschemes/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ipython_config.py -o $HOME/.ipython/profile_default/ipython_config.py

unset POWERLINE_INSTALLATION
```

### Specific to Linux Mint

```bash
# Load all dumped configuration
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/mint/org.dconf | dconf load /org/
```

### NVim

```
:PluginInstall
```

### Tmux

```
tmux [-u]
```

## Misc

### Ctrl+L clear terminal

If `^L` won't clear terminal, add line `"\C-l":'clear\n'` to `/etc/inputrc` at the end of the file to fix it.

### Kodi - some videos won't play

Try disabling/enabling hardware acceleration in `Settings -> Player -> Videos -> Allow hardware acceleration - ...`
