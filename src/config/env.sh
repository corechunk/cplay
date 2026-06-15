#!/usr/bin/env bash
declare -g VERSION="1.0.0.1"


# --- Environment & Engine Globals ---

declare -g TMP="/tmp/corechunk/cplay"
declare -g ACTIVE_ENGINE="raw"
declare -g MPV_SOCKET="$TMP/cplay-mpv.sock"
declare -g CPLAY_VERBOSE="false"
declare -g CPLAY_MODE="tui"
declare -g CPLAY_CURRENT_PAGE="main"
declare -g CPLAY_OLD_STTY=""
declare -g CPLAY_LAUNCH_FOLDER=""
declare -g CPLAY_SESSION_ACTIVE="false"

# Raw driver state variables
declare -g RAW_CURRENT_FILE=""
declare -g -i RAW_CURRENT_OFFSET=0
declare -g RAW_PAUSE_STATE="false"
declare -g RAW_PLAYER_PID=""

# Visualizer & Integration States
declare -g CAVA_STATUS="inactive"
declare -g CAVA_PID=""
declare -g CPLAY_MUTE_STATE="false"

# Metadata & Art State
declare -g -A CPLAY_META=()
declare -g CPLAY_META_ART=""
declare -g CPLAY_META_DIR="${TMP}/metas"

# Kitty support detection
if [[ "$TERM" == *kitty* || -n "$KITTY_WINDOW_ID" ]]; then
    declare -g CPLAY_KITTY_SUPPORT="true"
else
    declare -g CPLAY_KITTY_SUPPORT="false"
fi
