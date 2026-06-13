#!/usr/bin/env bash

# --- Raw PulseAudio/PipeWire Backend Driver ---

# Internal helper to detect sound card command (Pipewire or Pulse)
_detect_output_cmd() {
    if command -v pw-cat >/dev/null 2>&1; then
        echo "pw-cat --playback"
    elif command -v pacat >/dev/null 2>&1; then
        echo "pacat --playback"
    else
        echo ""
    fi
}

driver_raw_init() {
    # No daemon start required for raw driver
    :
}

driver_raw_play() {
    local source="$1"
    RAW_CURRENT_FILE="$source"
    RAW_CURRENT_OFFSET=0
    RAW_PAUSE_STATE="false"
    
    local out_cmd
    local out_format
    if command -v pw-cat >/dev/null 2>&1; then
        out_cmd="pw-cat --playback --raw"
        out_format="--format=s16"
    elif command -v pacat >/dev/null 2>&1; then
        out_cmd="pacat --playback"
        out_format="--format=s16le"
    else
        echo "Error: No PipeWire (pw-cat) or PulseAudio (pacat) found." >&2
        return 1
    fi

    # Clean up old running processes
    local ffmpeg_old_pid
    ffmpeg_old_pid=$(bl_pid_status "raw_ffmpeg" 2>/dev/null) # wait, let's just kill them if stored
    # We can fetch directly from BL_PIDS
    if [[ -n "${BL_PIDS["raw_backend"]}" ]]; then
        kill -TERM "${BL_PIDS["raw_backend"]}" 2>/dev/null
    fi
    if [[ -n "${BL_PIDS["raw_ffmpeg"]}" ]]; then
        kill -TERM "${BL_PIDS["raw_ffmpeg"]}" 2>/dev/null
    fi

    # Set up FIFO
    local fifo="$TMP/cplay-raw.fifo"
    rm -f "$fifo"
    mkfifo "$fifo"

    # Spawn ffmpeg writing to FIFO (resample to 44100Hz 2 Channels)
    ffmpeg -ss "$RAW_CURRENT_OFFSET" -i "$RAW_CURRENT_FILE" -ar 44100 -ac 2 -f s16le -acodec pcm_s16le - 2>"$TMP/cplay-raw.log" > "$fifo" &
    local ffmpeg_pid=$!
    bl_pid_store "raw_ffmpeg" "$ffmpeg_pid"

    # Spawn audio player reading from FIFO
    $out_cmd $out_format --rate=44100 --channels=2 "$fifo" 2>>"$TMP/cplay-raw.log" &
    RAW_PLAYER_PID=$!
    bl_pid_store "raw_backend" "$RAW_PLAYER_PID"
}

driver_raw_pause_toggle() {
    if [[ -z "$RAW_PLAYER_PID" ]]; then return; fi
    
    if [[ "$RAW_PAUSE_STATE" == "false" ]]; then
        # Pause pipeline
        kill -STOP "$RAW_PLAYER_PID" 2>/dev/null
        RAW_PAUSE_STATE="true"
    else
        # Resume pipeline
        kill -CONT "$RAW_PLAYER_PID" 2>/dev/null
        RAW_PAUSE_STATE="false"
    fi
}

driver_raw_seek() {
    local seconds="$1" # relative offset, e.g. "+10" or "-10"
    if [[ -z "$RAW_PLAYER_PID" || -z "$RAW_CURRENT_FILE" ]]; then return; fi

    # Update current offset estimation (stub: in final app this will track elapsed time)
    # For now, let's update by relative seconds
    RAW_CURRENT_OFFSET=$(( RAW_CURRENT_OFFSET + seconds ))
    if (( RAW_CURRENT_OFFSET < 0 )); then RAW_CURRENT_OFFSET=0; fi

    local out_cmd
    local out_format
    if command -v pw-cat >/dev/null 2>&1; then
        out_cmd="pw-cat --playback --raw"
        out_format="--format=s16"
    elif command -v pacat >/dev/null 2>&1; then
        out_cmd="pacat --playback"
        out_format="--format=s16le"
    else
        return 1
    fi

    # Clean up old running processes
    if [[ -n "${BL_PIDS["raw_backend"]}" ]]; then
        kill -TERM "${BL_PIDS["raw_backend"]}" 2>/dev/null
    fi
    if [[ -n "${BL_PIDS["raw_ffmpeg"]}" ]]; then
        kill -TERM "${BL_PIDS["raw_ffmpeg"]}" 2>/dev/null
    fi

    # Set up FIFO
    local fifo="$TMP/cplay-raw.fifo"
    rm -f "$fifo"
    mkfifo "$fifo"

    # Spawn ffmpeg writing to FIFO (resample to 44100Hz 2 Channels)
    ffmpeg -ss "$RAW_CURRENT_OFFSET" -i "$RAW_CURRENT_FILE" -ar 44100 -ac 2 -f s16le -acodec pcm_s16le - 2>"$TMP/cplay-raw.log" > "$fifo" &
    local ffmpeg_pid=$!
    bl_pid_store "raw_ffmpeg" "$ffmpeg_pid"

    # Spawn audio player reading from FIFO
    $out_cmd $out_format --rate=44100 --channels=2 "$fifo" 2>>"$TMP/cplay-raw.log" &
    RAW_PLAYER_PID=$!
    bl_pid_store "raw_backend" "$RAW_PLAYER_PID"
}

driver_raw_volume() {
    local change="$1" # e.g. "5" or "-5"
    if [[ "$change" =~ ^- ]]; then
        local val="${change#-}"
        if command -v wpctl >/dev/null 2>&1; then
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${val}%-"
        elif command -v pactl >/dev/null 2>&1; then
            pactl set-sink-volume @DEFAULT_SINK@ "-${val}%"
        fi
    else
        if command -v wpctl >/dev/null 2>&1; then
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${change}%+"
        elif command -v pactl >/dev/null 2>&1; then
            pactl set-sink-volume @DEFAULT_SINK@ "+${change}%"
        fi
    fi
}

driver_raw_status() {
    if [[ -n "$RAW_PLAYER_PID" ]] && kill -0 "$RAW_PLAYER_PID" 2>/dev/null; then
        if [[ "$RAW_PAUSE_STATE" == "true" ]]; then
            echo "paused (PID: $RAW_PLAYER_PID)"
        else
            echo "playing (PID: $RAW_PLAYER_PID)"
        fi
        return 0
    fi
    echo "inactive"
    return 1
}
