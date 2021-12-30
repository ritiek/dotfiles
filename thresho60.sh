#!/bin/bash

echo 60 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold 
