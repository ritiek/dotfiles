#
# qBittorrent Gotify Notification Script
# Sends formatted notifications when torrents are added/completed
#
# Usage:
# $ sh qbittorrent-notify.sh "Torrent added" "%N" "%L" "%G" "%F" "%D" "%C" "%Z" "%T" "%I"
#

# Configuration
GOTIFY_URL="http://pilab.lion-zebra.ts.net:8893"
# @GOTIFY_TOKEN_FILE@ is substituted at build time (see nixarr.nix) with the
# sops-nix decrypted secret path; the token itself is never embedded here.
GOTIFY_TOKEN=$(cat "@GOTIFY_TOKEN_FILE@")
PRIORITY=3

# Torrent parameters from qBittorrent
TITLE="$1"
TORRENT_NAME="${2:-%N}"
CATEGORY="${3:-%L}"
TAGS="${4:-%G}"
CONTENT_PATH="${5:-%F}"
SAVE_PATH="${6:-%D}"
FILE_COUNT="${7:-%C}"
TORRENT_SIZE="${8:-%Z}"
TRACKER="${9:-%T}"
INFO_HASH_V1="${10:-%I}"

# Convert bytes to human-readable format
human_readable_size() {
    bytes=$1

    # Handle negative or invalid values
    case "$bytes" in
        -1) echo "Unknown"; return ;;
        ''|*[!0-9-]*) echo "$bytes"; return ;;
        -*) echo "Unknown"; return ;;
    esac

    index=0
    size=$bytes

    # Convert to appropriate unit
    while [ "$size" -ge 1024 ] && [ $index -lt 4 ]; do
        size=$((size / 1024))
        index=$((index + 1))
    done

    case $index in
        0) echo "${size} B" ;;
        1) echo "${size} KB" ;;
        2) echo "${size} MB" ;;
        3) echo "${size} GB" ;;
        4) echo "${size} TB" ;;
    esac
}

# Format the message with torrent details
format_message() {
    size_human=$(human_readable_size "$TORRENT_SIZE")
    msg="Name: $TORRENT_NAME\n"

    # Only show size if it's valid
    [ "$TORRENT_SIZE" != "-1" ] && msg="${msg}Size: $size_human\n"

    # Only show file count if it's valid (hide completely if -1)
    [ "$FILE_COUNT" != "-1" ] && msg="${msg}Files: $FILE_COUNT\n"

    [ -n "$CATEGORY" ] && [ "$CATEGORY" != "N/A" ] && [ "$CATEGORY" != "%L" ] && msg="${msg}Category: $CATEGORY\n"
    [ -n "$TAGS" ] && [ "$TAGS" != "N/A" ] && [ "$TAGS" != "%G" ] && msg="${msg}Tags: $TAGS\n"
    [ -n "$CONTENT_PATH" ] && [ "$CONTENT_PATH" != "%F" ] && msg="${msg}Content Path: $CONTENT_PATH\n"
    msg="${msg}Save Path: $SAVE_PATH\n"
    [ -n "$TRACKER" ] && [ "$TRACKER" != "N/A" ] && [ "$TRACKER" != "%T" ] && msg="${msg}Tracker: $TRACKER\n"

    # POSIX-compatible substring extraction
    hash_short=$(echo "$INFO_HASH_V1" | cut -c1-16)
    msg="${msg}Info Hash: ${hash_short}..."

    printf "%b" "$msg"
}

# Send notification to Gotify
MESSAGE=$(format_message)

curl -s -X POST "$GOTIFY_URL/message?token=$GOTIFY_TOKEN" \
    -F "title=$TITLE" \
    -F "message=$MESSAGE" \
    -F "priority=$PRIORITY" \
    > /dev/null

# Log success (optional)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Notification sent for: $TORRENT_NAME" >&2
