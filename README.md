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
                    ffmpeg \
                    aria2 \
                    undistract-me \
                    mpv \
                    git \
                    xclip \
                    python3-pip \
                    openssh-server \
                    zsh

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

```bash
# Wavebox
wget -qO - https://wavebox.io/dl/client/repo/archive.key | sudo apt-key add -
echo "deb https://wavebox.io/dl/client/repo/ x86_64/" | sudo tee --append /etc/apt/sources.list.d/wavebox.list
sudo apt update
sudo apt install wavebox
```

## Configuration

```bash
# My lovely machines
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.ssh/authorized_keys -o ~/.ssh/authorized_keys

# Display current battery % with `$ battery`
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/battery.sh -o ~/.local/bin/battery
chmod +x ~/.local/bin/battery

# NVim configuration
git clone https://github.com/VundleVim/Vundle.vim.git ~/.config/nvim/bundle/Vundle.vim
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/sysinit.vim -o ~/.config/nvim/sysinit.vim

# Shell configuration files
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.bashrc -o ~/.bashrc
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.profile -o ~/.profile

# Tmux configuration
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
curl https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf -o ~/.tmux.conf
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.tmux.conf.local -o ~/.tmux.conf.local

# Mpv configuration
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/mpv.conf -o ~/.config/mpv/mpv.conf
```

### Switch to Zsh
```bash
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.zshrc -o ~/.zshrc
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.zprofile -o ~/.zprofile
git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
# Enter your password when prompted
chsh -s $(which zsh)
```

### Configure Powerline prompt

```bash
# Configure the PYTHON3 variable based on your python version
# Find the python version and powerline installation location
# with `pip3 show powerline-status`

PYTHON3="python3.6"
POWERLINE_INSTALLATION=$HOME/.local/lib/$PYTHON3/site-packages/powerline

POWERLINE_BASH_CONFIG=$POWERLINE_INSTALLATION/bindings/bash/powerline.sh
POWERLINE_ZSH_CONFIG=$POWERLINE_INSTALLATION/bindings/zsh/powerline.zsh

curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/config.json -o $POWERLINE_INSTALLATION/config_files/config.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek_shell_theme.json -o $POWERLINE_INSTALLATION/config_files/themes/shell/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ritiek_colorscheme.json -o $POWERLINE_INSTALLATION/config_files/colorschemes/ritiek.json
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ipython_config.py -o $HOME/.ipython/profile_default/ipython_config.py
```
```bash
# Launch Powerline theme with .bashrc
echo >> $HOME/.bashrc
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/powerline-daemon-runner >> $HOME/.bashrc
echo "# Load our powerline theme" >> $HOME/.bashrc
echo "source $POWERLINE_BASH_CONFIG" >> $HOME/.bashrc
```
```bash
# Launch Powerline theme with .zshrc
echo >> $HOME/.zshrc
curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/powerline-daemon-runner >> $HOME/.zshrc
echo "# Load our powerline theme" >> $HOME/.zshrc
echo "source $POWERLINE_ZSH_CONFIG" >> $HOME/.zshrc
```
```bash
# unset everything
unset PYTHON3
unset POWERLINE_INSTALLATION
unset POWERLINE_BASH_CONFIG
unset POWERLINE_ZSH_CONFIG
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
