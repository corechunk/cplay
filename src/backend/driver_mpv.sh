#!/usr/bin/env bash

# --- MPV Player Backend Driver ---

driver_mpv_init() {
    # Start MPV in idle, headless mode with IPC enabled
    mpv --idle --no-video --input-ipc-server="$MPV_SOCKET" --quiet >/dev/null 2>&1 &
    bl_pid_store "mpv_backend" $!
}

driver_mpv_play() {
    local source="$1"
    # Send JSON IPC load command to MPV socket
    echo '{"command": ["loadfile", "'"$source"'"]}' | socat - "$MPV_SOCKET" >/dev/null 2>&1
}

driver_mpv_pause_toggle() {
    # Toggle pause state in MPV
    echo '{"command": ["cycle", "pause"]}' | socat - "$MPV_SOCKET" >/dev/null 2>&1
}

driver_mpv_seek() {
    local seconds="$1"
    # Seek relatively by seconds (+10 or -10)
    echo '{"command": ["seek", '"$seconds"', "relative"]}' | socat - "$MPV_SOCKET" >/dev/null 2>&1
}

driver_mpv_volume() {
    local change="$1" # e.g. "5" or "-5"
    echo '{"command": ["add", "volume", '"$change"']}' | socat - "$MPV_SOCKET" >/dev/null 2>&1
}

driver_mpv_status() {
    if [[ -S "$MPV_SOCKET" ]]; then
        if echo '{"command": ["get_property", "pause"]}' | socat - "$MPV_SOCKET" >/dev/null 2>&1; then
            echo "active"
            return 0
        fi
    fi
    echo "inactive"
    return 1
}
