#!/bin/bash

BATTERYPATH=/sys/class/power_supply/BAT0/capacity
if [ -f $BATTERYPATH ]; then
    cat $BATTERYPATH
fi
