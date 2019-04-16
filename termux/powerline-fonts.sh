#!/bin/bash

FONTPATH="~/.termux"
mkdir -p $FONTPATH
curl https://github.com/powerline/fonts/raw/master/LiberationMono/Literation%20Mono%20Powerline.ttf -o $FONTPATH/fonts.ttf
termux-reload-settings
