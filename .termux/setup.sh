#!/data/data/com.termux/files/usr/bin/bash

function install() {
    echo "Installing powerline fonts"
    FONTPATH=~/.termux
    mkdir -p $FONTPATH
    curl https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/InconsolataGo/Regular/complete/InconsolataGo%20Nerd%20Font%20Complete.ttf -o $FONTPATH/font.ttf
    termux-reload-settings

    echo "Setting up termux-url-opener for downloading tracks"
    mkdir -p ~/bin
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.termux/termux-url-opener -o ~/bin/termux-url-opener
}

install
