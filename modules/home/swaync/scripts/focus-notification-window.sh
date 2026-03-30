#!/usr/bin/env bash

# Focus window by app_id when a notification is clicked
# Environment variable $SWAYNC_APP_NAME is set by swaync

if [ -z "$SWAYNC_APP_NAME" ]; then
    echo "Error: SWAYNC_APP_NAME is not set" >&2
    exit 1
fi

# Find window with matching app_id and focus it
WINDOW_ID=$(niri msg --json windows | jq -r --arg app_name "$SWAYNC_APP_NAME" '.[] | select(.app_id == $app_name) | .id' | head -1)

if [ -n "$WINDOW_ID" ]; then
    niri msg action focus-window "$WINDOW_ID"
else
    echo "No window found with app_id: $SWAYNC_APP_NAME" >&2
fi
