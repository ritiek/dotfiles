#!/bin/bash

upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
secs=$((upSeconds%60))
mins=$((upSeconds/60%60))
hours=$((upSeconds/3600%24))
days=$((upSeconds/86400))
UPTIME=$(printf "%dd%02dh%02dm" "$days" "$hours" "$mins")
echo $UPTIME
