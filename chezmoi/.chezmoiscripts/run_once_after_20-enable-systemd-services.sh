#!/bin/sh

sudo systemctl enable --now tailscaled
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now swayosd-libinput-backend.service

sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
