#!/usr/bin/env bash

# --- Unified Backend Player Engine Coordinator ---

engine_init() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        if command -v mpv >/dev/null 2>&1; then
            driver_mpv_init
        else
            echo "Warning: mpv not found. Falling back to raw mode." >&2
            ACTIVE_ENGINE="raw"
            driver_raw_init
        fi
    else
        driver_raw_init
    fi
}

cplay_play() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        driver_mpv_play "$1"
    else
        driver_raw_play "$1"
    fi
}

cplay_pause() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        driver_mpv_pause_toggle
    else
        driver_raw_pause_toggle
    fi
}

cplay_seek() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        driver_mpv_seek "$1"
    else
        driver_raw_seek "$1"
    fi
}

cplay_volume() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        driver_mpv_volume "$1"
    else
        driver_raw_volume "$1"
    fi
}

cplay_status() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        driver_mpv_status
    else
        driver_raw_status
    fi
}

cplay_mute() {
    if [[ "$ACTIVE_ENGINE" == "mpv" ]]; then
        if [[ "$CPLAY_MUTE_STATE" == "false" ]]; then
            echo '{"command": ["set_property", "mute", true]}' | socat - "$MPV_SOCKET" >/dev/null 2>&1
            CPLAY_MUTE_STATE="true"
        else
            echo '{"command": ["set_property", "mute", false]}' | socat - "$MPV_SOCKET" >/dev/null 2>&1
            CPLAY_MUTE_STATE="false"
        fi
    else
        if [[ "$CPLAY_MUTE_STATE" == "false" ]]; then
            if command -v wpctl >/dev/null 2>&1; then
                wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
            elif command -v pactl >/dev/null 2>&1; then
                pactl set-sink-mute @DEFAULT_SINK@ toggle
            fi
            CPLAY_MUTE_STATE="true"
        else
            if command -v wpctl >/dev/null 2>&1; then
                wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
            elif command -v pactl >/dev/null 2>&1; then
                pactl set-sink-mute @DEFAULT_SINK@ toggle
            fi
            CPLAY_MUTE_STATE="false"
        fi
    fi
}

