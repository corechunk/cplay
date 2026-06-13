#!/usr/bin/env bash

# --- Playlist & Queue Manager ---

cplay_next() {
    if (( ${#CPLAY_QUEUE[@]} == 0 )); then
        return
    fi
    CPLAY_CURRENT_INDEX=$(( (CPLAY_CURRENT_INDEX + 1) % ${#CPLAY_QUEUE[@]} ))
    cplay_play "${CPLAY_QUEUE[$CPLAY_CURRENT_INDEX]}"
}

cplay_prev() {
    if (( ${#CPLAY_QUEUE[@]} == 0 )); then
        return
    fi
    CPLAY_CURRENT_INDEX=$(( (CPLAY_CURRENT_INDEX - 1 + ${#CPLAY_QUEUE[@]}) % ${#CPLAY_QUEUE[@]} ))
    cplay_play "${CPLAY_QUEUE[$CPLAY_CURRENT_INDEX]}"
}
