#!/bin/bash

# For turning off display/adjusting brightness on the Asus Zenbook Screenpad v2

if [ $1 -lt 1 ]; then
  xrandr --output HDMI-2 --off
else
  xrandr --auto --output HDMI-2 --mode 1080x2160 --pos 0x1080; xrandr --output HDMI-2 --rotate right
  echo $1 | sudo tee /sys/class/leds/asus::screenpad/brightness
fi
