#!/usr/bin/env bash

# --- Environment & Engine Globals ---

declare -g TMP="/tmp/corechunk/cplay"
declare -g ACTIVE_ENGINE="raw"
declare -g MPV_SOCKET="$TMP/cplay-mpv.sock"
declare -g CPLAY_VERBOSE="false"
declare -g CPLAY_TUI_MODE="false"
declare -g CPLAY_CURRENT_PAGE="main"
declare -g CPLAY_OLD_STTY=""
declare -g CPLAY_LAUNCH_FOLDER=""

# Raw driver state variables
declare -g RAW_CURRENT_FILE=""
declare -g -i RAW_CURRENT_OFFSET=0
declare -g RAW_PAUSE_STATE="false"
declare -g RAW_PLAYER_PID=""

# Visualizer & Integration States
declare -g CAVA_STATUS="inactive"
declare -g CAVA_PID=""
declare -g CPLAY_MUTE_STATE="false"
