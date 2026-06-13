#!/usr/bin/env bash

# --- Playlist & Queue State ---

declare -g -a CPLAY_QUEUE=()
declare -g -i CPLAY_CURRENT_INDEX=0
declare -g -A CPLAY_SOURCES=()
