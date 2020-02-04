#!/data/data/com.termux/files/usr/bin/bash

function install() {
    echo "Installing powerline fonts"
    FONTPATH=~/.termux
    mkdir -p $FONTPATH
    curl https://raw.githubusercontent.com/powerline/fonts/master/LiberationMono/Literation%20Mono%20Powerline.ttf -o $FONTPATH/font.ttf
    termux-reload-settings

    echo "Setting up termux-url-opener for downloading tracks"
    mkdir -p ~/bin
    curl https://raw.githubusercontent.com/ritiek/dotfiles/master/.termux/termux-url-opener -o ~/bin/termux-url-opener
}

install
