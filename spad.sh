#!/bin/bash

# For turning off display/adjusting brightness on the Asus Zenbook Screenpad v2

if [ $1 -lt 1 ]; then
  # Switch off display
  xrandr --output HDMI-2 --off
  # Recalibrate touchscreen
  xinput map-to-output 12 eDP-1
else
  # Correct touchpad display orientation
  xrandr --auto --output HDMI-2 --mode 1080x2160 --pos 0x1080; xrandr --output HDMI-2 --rotate right
  # Recalibrate touchscreen
  xinput map-to-output 12 eDP-1
  # Set touchpad brightness
  echo $1 | sudo tee /sys/class/leds/asus::screenpad/brightness
fi
