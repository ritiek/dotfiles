#!/bin/bash

function install() {
    if [ -f "/etc/arch-release" ]; then
        is_arch=true
    else
        is_arch=false
    fi

    echo "I'll ask some questions, READ THEM CAREFULLY BEFORE ANSWERING y OR n."
    echo

    echo "Install Zsh configuration and set it as the default shell? (y/N) "
    read to_install_zsh

    if [ "$to_install_zsh" == "y" ]; then
        echo "Also install Powerline themes (for Zsh, Tmux, IPython)? (y/N) "
        read to_install_powerline
    else
        to_install_powerline='n'
    fi

    echo "Install Kitty (terminal emulator) and set it as default? (y/N) "
    read to_install_kitty

    echo "Install Spotify (x86-x64 only) (y/N) "
    read to_install_spotify

    echo "Install Rust Compiler and some of its really nice packages (ripgrep and like)? (y/N) "
    read to_install_rust

    echo "Install miscellaneous packages (mostly music-related tools I care about - mps-youtube, etc.)? (y/N) "
    read to_install_miscellaneous

    echo "Apply my customized KDE's look & feel? (y/N) "
    read to_kde_feel

    if [ "$to_kde_feel" == "y" ]; then
        to_gnome_feel='n'
    else
        echo "Apply my customized GNOME's look & feel? (y/N) "
        read to_gnome_feel
    fi

    if [[ "$to_kde_feel" == "y" || "$to_gnome_feel" == "y" ]]; then
        to_cinnamon_feel='n'
    else
        echo "Apply my customized Cinnamon's look & feel? (y/N) "
        read to_cinnamon_feel
    fi

    echo "Copy all my device public keys to ~/.ssh/authorized_keys (THIS SHOULD BE A BIG NO, UNLESS YOU ARE ME!)? (y/N) "
    read to_copy_ssh_keys

    echo "Override ~/.gitconfig (THIS SHOULD BE A BIG NO, UNLESS YOU ARE ME!)? (y/N) "
    read to_override_gitconfig

    if [[ $is_arch == true ]]; then
        echo "Run pacman -Syu? You should, to be safe. (Y/n) "
    else
        echo "Run apt update? You should, to be safe. (Y/n) "
    fi
    read to_update

    echo
    echo "Okay, that's all I need to know for now"

    echo "Make sure to keep an eye on this script, since it will prompt when "
    echo "- Setting locales (to choose the default locale)"
    echo "- Changing default shell (for su password)"
    echo "You should be safe to wander off, once these have been taken care of"
    echo
    sleep 1s

    if [[ $is_arch == false ]]; then
        echo "You'll need to set the default locale to 'en_US.UTF8' manually in the next step"
        echo "Hit enter to continue"
        read
        sudo dpkg-reconfigure locales
        echo
    fi

    if [ "$to_update" == "n" ]; then
        echo "Skip update"
    else
        if [[ $is_arch == true ]]; then
            echo "Calling pacman -Syu"
            sudo pacman -Syu
        else
            echo "Calling apt update"
            sudo apt update
        fi
        echo
    fi

    if [[ $is_arch == true ]]; then
        echo "Installing useful tools via pacamn -S"
        sudo pacman --noconfirm -S neovim \
                                   tmux \
                                   ffmpeg \
                                   aria2 \
                                   mpv \
                                   git \
                                   hub \
                                   base-devel \
                                   linux-mainline \
                                   xclip \
                                   dbus \
                                   nmap \
                                   python-pip \
                                   openssh \
                                   openssl-1.0 \
                                   clang \
                                   gcc \
                                   imagemagick \
                                   pamac-cli
                                   xdotool \
                                   tree \
                                   xdg-desktop-portal-gtk \
                                   xxd-standalone \
                                   strace \
                                   virt-manager \
                                   qemu \
                                   vde2 \
                                   ebtables \
                                   dnsmasq \
                                   bridge-utils \
                                   openbsd-netcat \
                                   unzip \
                                   libvorbis \
                                   openal \
                                   sdl2 \
                                   pkgconf \
                                   dbus-python \
                                   make \
                                   wireguard-tools \
                                   noto-fonts-emoji \
                                   glava

        pamac build --no-confirm scrcpy \
                                 netdiscover \
                                 chiaki \
                                 plasma5-applets-eventcalendar \
                                 sc-controller \
                                 brave-bin \
                                 python38 \
                                 zoom \
                                 slack-desktop \
                                 spotify-adblock \
                                 auto-cpufreq \
                                 mongodb-bin \
                                 postman-bin
    else
        echo "Installing useful tools via apt install"
        sudo apt install -y software-properties-common \
                            neovim \
                            tmux \
                            ffmpeg \
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
                            fonts-noto-color-emoji
        sudo apt install -y hub
        sudo apt install -y btfs
    fi
    echo

    if [ "$to_install_zsh" == "y" ]; then
        echo "Installing Zsh"
        if [[ $is_arch == true ]]; then
            sudo pacman --noconfirm -S zsh
        else
            sudo apt install -y zsh
        fi
        echo

        echo "Changing default shell to Zsh"
        # Enter your password when prompted
        sudo chsh $USER -s $(which zsh)
        echo
    else
        echo "Skip installing Zsh"
    fi

    echo "Installing standard Python packages: setuptools, wheel"
    pip3 install setuptools wheel ipython --user -U
    echo

    if [ "$to_install_powerline" == "y" ]; then
        echo "Installing powerline prompt Python packages"
        mkdir -p ~/.local/share/fonts

        wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/InconsolataGo/Bold/complete/InconsolataGo%20Bold%20Nerd%20Font%20Complete%20Mono.ttf -O ~/.local/share/fonts/InconsolataGo\ Bold\ Nerd\ Font\ Complete\ Mono.ttf
        wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/InconsolataGo/Regular/complete/InconsolataGo%20Nerd%20Font%20Complete%20Mono.ttf -O ~/.local/share/fonts/InconsolataGo\ Nerd\ Font\ Complete\ Mono.ttf

        wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FantasqueSansMono/Regular/complete/Fantasque%20Sans%20Mono%20Regular%20Nerd%20Font%20Complete%20Mono.ttf -O ~/.local/share/fonts/Fantasque\ Sans\ Mono\ Regular\ Nerd\ Font\ Complete\ Mono.ttf
        wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FantasqueSansMono/Italic/complete/Fantasque%20Sans%20Mono%20Italic%20Nerd%20Font%20Complete%20Mono.ttf -O ~/.local/share/fonts/Fantasque\ Sans\ Mono\ Italic\ Nerd\ Font\ Complete\ Mono.ttf
        wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FantasqueSansMono/Bold/complete/Fantasque%20Sans%20Mono%20Bold%20Nerd%20Font%20Complete%20Mono.ttf -O ~/.local/share/fonts/Fantasque\ Sans\ Mono\ Bold\ Nerd\ Font\ Complete\ Mono.ttf
        wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/FantasqueSansMono/Bold-Italic/complete/Fantasque%20Sans%20Mono%20Bold%20Italic%20Nerd%20Font%20Complete%20Mono.ttf -O ~/.local/share/fonts/Fantasque\ Sans\ Mono\ Bold\ Italic\ Nerd\ Font\ Complete\ Mono.ttf


        pip3 install dbus-python --user -U
        pip3 install psutil --user -U
        pip3 install git+https://github.com/ritiek/powerline.git --user -U
        pip3 install powerline-gitstatus --user -U
        pip3 install git+https://github.com/mKaloer/powerline_mem_segment --user -U
        pip3 install powerline-cpu-temp --user -U
        echo
    else
        echo "Skip installing powerline"
    fi

    # echo "Replacing ~/.bashrc"
    # curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.bashrc -o ~/.bashrc

    if [ "$to_install_zsh" == "y" ]; then
        echo "Replacing ~/.profile"
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.profile -o ~/.profile
        echo
        echo "Replacing ~/.zprofile"
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.zprofile -o ~/.zprofile
        echo
        echo "Replacing ~/.zshrc"
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.zshrc -o ~/.zshrc
        echo

        echo "Sourcing newly zsh configuration"
        source ~/.profile
        source ~/.zprofile
        source ~/.zshrc
        echo
        echo "Installing Oh-My-Zsh!"
        git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh
        echo
        echo "Installing zsh-autosuggestions plugin"
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        echo
        echo "Installing zsh-syntax-highlightning plugin"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        echo
    else
        echo "Skip installing Zsh configuration files"
    fi

    # Tmux configuration
    echo "Installing Tmux configuration"
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.tmux.conf -o ~/.tmux.conf
    echo "Please run PREFIX+SHIFT+I manually to complete plugin installation in Tmux"
    sleep 3s
    echo

    if [ "$to_install_powerline" == "y" ]; then
        echo "Fetching powerline theme and colorscheme configuration"
        mkdir -p ~/.config/powerline
        cd ~/.config/powerline
        git init
        git remote add origin https://github.com/ritiek/dotfiles.git
        git config core.sparseCheckout true
        echo "powerline/config" >> .git/info/sparse-checkout
        git pull --depth=1 origin master
        mv powerline/config/* .
        rm -r powerline
        rm -rf .git

        cd -

        mkdir -p ~/.ipython/profile_default
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/ipython_config.py -o ~/.ipython/profile_default/ipython_config.py
        echo

        echo "Locating where powerline got installed..."
        POWERLINE_INSTALLATION=$(python3 -c "import powerline, inspect, os; print(os.path.dirname(inspect.getfile(powerline)))")
        echo "Powerline installation found in $POWERLINE_INSTALLATION"
        echo

        # Bash powerline theme
        # echo "Setting up powerline prompt for use with Bash"
        # POWERLINE_BASH_CONFIG=$POWERLINE_INSTALLATION/bindings/bash/powerline.sh
        # echo
        # echo "Appending powerline Bash specific code to ~/.bashrc"
        # echo >> ~/.bashrc
        # curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/powerline-daemon-runner >> ~/.bashrc
        # echo "# Load our powerline theme" >> ~/.bashrc
        # echo "source $POWERLINE_BASH_CONFIG" >> ~/.bashrc
        # echo

        # Zsh powerline theme
        echo "Locating Zsh powerline configuration..."
        POWERLINE_ZSH_CONFIG=$POWERLINE_INSTALLATION/bindings/zsh/powerline.zsh
        echo "Expecting in $POWERLINE_ZSH_CONFIG"
        echo
        echo "Appending powerline Zsh specific code to ~/.zshrc"
        echo >> ~/.zshrc
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/powerline/powerline-daemon-runner >> ~/.zshrc
        echo "# Load our powerline theme" >> ~/.zshrc
        echo "source $POWERLINE_ZSH_CONFIG" >> ~/.zshrc
        echo

        # Tmux powerline theme
        echo "Locating Tmux powerline configuration..."
        POWERLINE_TMUX_CONFIG=$POWERLINE_INSTALLATION/bindings/tmux/powerline.conf
        echo "Expecting in $POWERLINE_TMUX_CONFIG"
        echo
        echo "Appending powerline Tmux specific code to ~/.tmux.conf"
        echo >> ~/.tmux.conf
        echo "# Load our powerline theme" >> ~/.tmux.conf
        echo "source $POWERLINE_TMUX_CONFIG" >> ~/.tmux.conf
        echo
    fi

    unset POWERLINE_INSTALLATION
    unset POWERLINE_ZSH_CONFIG
    unset POWERLINE_BASH_CONFIG


    if [ "$to_install_kitty" == "y" ]; then
        curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
        ln -s ~/.local/kitty.app/bin/kitty ~/.local/bin/kitty
        mkdir -p ~/.local/share/applications
        cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications
        sed -i "s/Icon\=kitty/Icon\=\/home\/$USER\/.local\/kitty.app\/share\/icons\/hicolor\/256x256\/apps\/kitty.png/g" ~/.local/share/applications/kitty.desktop
        mkdir -p ~/.config/kitty
        curl https://i.imgur.com/5oD0uqi.png >> ~/.config/kitty/background.png
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/kitty.conf >> ~/.config/kitty/kitty.conf
        sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator ~/.local/bin/kitty 50
        sudo update-alternatives --set x-terminal-emulator ~/.local/bin/kitty
    fi

    if [ "$to_copy_ssh_keys" == "y" ]; then
        # My lovely machines
        echo "Copying SSH keys to ~/.ssh/authorized_keys"
        mkdir -p ~/.ssh
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.ssh/authorized_keys >> ~/.ssh/authorized_keys
    else
        echo "Skip copying SSH keys"
    fi

    if [ "$to_override_gitconfig" == "y" ]; then
        echo "Overriding ~/.gitconfig"
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.gitconfig >> ~/.gitconfig
    fi

    # Display current battery % with `$ battery`
    echo "Fetching script to display remaining battery % in ~/.local/bin/battery"
    mkdir -p ~/.local/bin/
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/battery.sh -o ~/.local/bin/battery
    chmod +x ~/.local/bin/battery
    echo

    # NVim configuration
    echo "Installing NeoVim configuration"
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.config/nvim/bundle/Vundle.vim
    mkdir -p ~/.config/nvim
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/init.vim -o ~/.config/nvim/init.vim
    mkdir -p ~/.local/share/fonts
    curl https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf \
        -o ~/.local/share/fonts/Droid\ Sans\ Mono\ for\ Powerline\ Nerd\ Font\ Complete.otf
    nvim -c "PluginInstall" -c "q" -c "q"
    echo

    # Mpv configuration
    echo "Installing Mpv configuration"
    mkdir -p ~/.config/mpv
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/mpv.conf -o ~/.config/mpv/mpv.conf
    echo

    # Radare2 configuration
    echo "Replacing ~/.radare2rc"
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.radare2rc -o ~/.radare2rc
    echo

    if [[ $is_arch == true ]]; then
        # GLava configuration
        echo "Installing GLava configuration"
        glava --copy-config
        mkdir -p ~/.config/glava
        cd ~/.config/glava
        git init
        git remote add origin https://github.com/ritiek/dotfiles.git
        git config core.sparseCheckout true
        echo "glava" >> .git/info/sparse-checkout
        git pull --depth=1 origin master
        mv glava/* .
        rm -r glava
        rm -rf .git
        cd -
    fi

    if [ "$to_kde_feel" == "y" ]; then
        curl https://gitlab.com/cscs/transfuse/-/raw/master/transfuse.sh -o transfuse.sh
        chmod +x transfuse.sh
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/kde/ritiek_transfusion_20200828_0120.tar.gz -o ritiek_transfusion_20200828_0120.tar.gz
        echo
        echo 'Choose "$USER_transfusion_$DATE.tar.gz" here'
        ./transfuse.sh -r
    fi

    if [ "$to_gnome_feel" == "y" ]; then
        echo "Applying my GNOME's customized look & feel"
        sudo apt install -y gnome-shell-extensions gnome-shell chrome-gnome-shell
        mkdir -p ~/.local/share/gnome-shell
        cd ~/.local/share/gnome-shell
        git init
        git remote add origin https://github.com/ritiek/dotfiles.git
        git config core.sparseCheckout true
        echo "gnome/extensions" >> .git/info/sparse-checkout
        git pull --depth=1 origin master
        mv gnome/extensions .
        rm -r gnome
        rm -rf .git
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/gnome/org.dconf | dconf load /org/
    fi

    if [ "$to_cinnamon_feel" == "y" ]; then
        echo "Applying my Cinnamon's customized look & feel"
        curl https://raw.githubusercontent.com/ritiek/dotfiles/master/mint/org.dconf | dconf load /org/
    fi

    if [ "$to_install_spotify" == "y" ]; then
        echo "Installing Spotify"
        if [[ $is_arch == true ]]; then
            curl -sS https://download.spotify.com/debian/pubkey.gpg | gpg --import -
            pamac build --no-confirm spotify spotify-adblock-git
        else
            curl -sS https://download.spotify.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
            sudo apt-get update
            sudo apt-get install -y spotify-client
        fi
    fi

    if [ "$to_install_miscellaneous" == "y" ]; then
        pip3 install youtube-dl --user -U
        pip3 install git+https://github.com/mps-youtube/pafy.git --user -U
        pip3 install git+https://github.com/mps-youtube/mps-youtube.git --user -U
        pip3 install spotdl --user -U
    else
        echo "Skip installing miscellaneous stuff"
    fi


    if [ "$to_install_rust" == "y" ]; then
        echo "Installing Rust"
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        echo

        # Favourite Rust tools
        echo "Installing ripgrep"
        cargo install ripgrep
        echo
        echo "Installing fd-find"
        cargo install fd-find
        echo
        echo "Installing cargo-edit"
        cargo install cargo-edit
        echo
        echo "Installing sd"
        cargo install sd
        echo
        echo "Installing bat"
        cargo install bat
        echo
        echo "Installing simple-http-server"
        cargo install simple-http-server
        echo
        echo "Installing diskonaut"
        cargo install diskonaut
        echo
        echo "Installing bandwhich"
        cargo install bandwhich
        echo
        echo "Installing delta"
        cargo install git-delta
        echo
        echo "Installing cargo-edit"
        cargo install cargo-edit
        echo
        echo "Installing tealdeer (tldr)"
        cargo install tealdeer
        echo
    else
        echo "Skip Rust installation and awesome tools written in it"
    fi

    echo "Everything done!"
    echo
    echo "Please run PREFIX+SHIFT+I manually to complete plugin installation in Tmux"
}

install
