#!/bin/bash

BATTERYPATH=/sys/class/power_supply/BAT1/capacity
if [ -f $BATTERYPATH ]; then
    cat $BATTERYPATH
fi
