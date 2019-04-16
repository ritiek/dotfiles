#!/data/data/com.termux/files/usr/bin/bash

FONTPATH=~/.termux
mkdir -p $FONTPATH
curl https://raw.githubusercontent.com/powerline/fonts/master/LiberationMono/Literation%20Mono%20Powerline.ttf -o $FONTPATH/font.ttf
termux-reload-settings
