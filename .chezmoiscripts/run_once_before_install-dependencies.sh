#!/bin/sh

if [ -f "/etc/arch-release" ]; then
    is_arch=true
else
    is_arch=false
fi

if [[ $is_arch == false ]]; then
    echo "You'll need to set the default locale to 'en_US.UTF8' manually in the next step"
    echo "Hit enter to continue"
    read
    sudo dpkg-reconfigure locales
    echo
fi

if [[ $is_arch == true ]]; then
    sudo pacman-mirrors --fasttrack 20
    echo "Replace /etc/pacman.conf"
    sudo curl https://raw.githubusercontent.com/ritiek/dotfiles/chezmoi/etc/pacman.conf -o /etc/pacman.conf
    echo "Installing useful tools via pacman -S"
    sudo pacman --noconfirm -Syu neovim \
                                 zsh \
                                 wezterm \
                                 ffmpeg \
                                 aria2 \
                                 mpv \
                                 git \
                                 hub \
                                 base-devel \
                                 linux-headers \
                                 sof-firmware \
                                 xclip \
                                 dbus \
                                 nmap \
                                 python-pip \
                                 python-lsp-server \
                                 openssh \
                                 clang \
                                 gcc \
                                 imagemagick \
                                 pamac-cli \
                                 xdotool \
                                 tree \
                                 xdg-desktop-portal-gtk \
                                 strace \
                                 virt-manager \
                                 qemu \
                                 vde2 \
                                 ebtables \
                                 dnsmasq \
                                 bridge-utils \
                                 openbsd-netcat \
                                 unzip \
                                 bitwarden \
                                 bitwarden-cli \
                                 calibre \
                                 mitmproxy \
                                 libvorbis \
                                 openal \
                                 sdl2 \
                                 pkgconf \
                                 dbus-python \
                                 make \
                                 wireguard-tools \
                                 jq \
                                 noto-fonts-emoji \
                                 glava \
                                 xorg-xrandr \
                                 ctags \
                                 net-tools \
                                 reptyr \
                                 scrcpy \
                                 picocom \
                                 wl-clipboard \
                                 plasma-wayland-session \
                                 docker \
                                 docker-compose \
                                 ripgrep \
                                 git-delta \
                                 fd \
                                 sd \
                                 bandwhich \
                                 tailscale \
                                 avahi \
                                 python-pynvim \
                                 diskonaut
                                 # tmux

    echo "Replacing /etc/pamac.conf"
    sudo curl https://raw.githubusercontent.com/ritiek/dotfiles/chezmoi/etc/pamac.conf -o /etc/pamac.conf
    pamac build --no-confirm netdiscover \
                             chiaki \
                             plasma5-applets-eventcalendar \
                             sc-controller \
                             zoom \
                             slack-desktop \
                             auto-cpufreq \
                             mongodb-bin \
                             postman-bin \
                             touchegg \
                             wlr-randr \
                             google-chrome \
                             protonvpn \
                             touche
                             # helix-git
    pamac build --no-confirm spotify-adblock \
                             spotify-remove-ad-banner
    # Enables hostname.local domains on local network, making stuff like below possible:
    # ssh pi@raspberrypi.local
    sudo systemctl enable avahi-daemon \
                          auto-cpufreq
else
    sudo apt update
    echo "Installing useful tools via apt install"
    sudo apt install -y software-properties-common \
                        neovim \
                        tmux \
                        ffmpeg \
                        zsh \
                        aria2 \
                        undistract-me \
                        mpv \
                        git \
                        xclip \
                        python3-pip \
                        dbus \
                        nmap \
                        python-dev \
                        python3-dev \
                        openssh-server \
                        libssl-dev \
                        libclang-dev \
                        netdiscover \
                        imagemagick \
                        ctags \
                        fonts-noto-color-emoji
    sudo apt install -y hub
    sudo apt install -y btfs
fi

echo
rm -rf ~/.oh-my-zsh
echo "Installing Oh-My-Zsh"
KEEP_ZSHRC="yes" RUNZSH="no" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo
echo "Installing zsh-autosuggestions plugin"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
echo
echo "Installing zsh-syntax-highlightning plugin"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
echo
echo "Installing powerlevel10k"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
echo

if [[ $is_arch == false ]]; then
    pip3 install pynvim
fi

nvim -c "q"
# echo
# glava --copy-config
