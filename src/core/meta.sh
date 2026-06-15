#!/usr/bin/env bash

# --- Track Metadata & Cover Art Loader ---

check_kitty_support() {
    # Dynamically verify Kitty graphics protocol support
    if command -v kitty >/dev/null 2>&1 && kitty +kitten query >/dev/null 2>&1; then
        CPLAY_KITTY_SUPPORT="true"
    else
        CPLAY_KITTY_SUPPORT="false"
    fi
}

cplay_format_duration() {
    local seconds="${1%.*}"
    if [[ -z "$seconds" || ! "$seconds" =~ ^[0-9]+$ ]]; then
        echo "00:00"
        return
    fi
    local h=$(( seconds / 3600 ))
    local m=$(( (seconds % 3600) / 60 ))
    local s=$(( seconds % 60 ))
    if (( h > 0 )); then
        printf "%02d:%02d:%02d\n" $h $m $s
    else
        printf "%02d:%02d\n" $m $s
    fi
}

cplay_meta_load() {
    local filepath="$1"
    
    # Reset existing meta
    CPLAY_META=()
    CPLAY_META_ART=""
    
    if [[ -z "$filepath" ]]; then
        return
    fi

    # Set default values
    local base="${filepath##*/}"
    CPLAY_META[title]="${base%.*}"
    CPLAY_META[artist]="Unknown Artist"
    CPLAY_META[album]="Unknown Album"
    CPLAY_META[genre]="Unknown"
    CPLAY_META[date]=""
    CPLAY_META[duration]="00:00"
    CPLAY_META[filepath]="$filepath"

    # Only load if it's a file (URLs don't easily probe locally without delay)
    if [[ ! -f "$filepath" ]]; then
        return
    fi

    mkdir -p "$CPLAY_META_DIR"
    chmod 755 "$CPLAY_META_DIR" 2>/dev/null || true

    if command -v ffprobe >/dev/null 2>&1; then
        local line
        while IFS= read -r line; do
            if [[ "$line" =~ ^TAG:([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local val="${BASH_REMATCH[2]}"
                key="${key,,}"
                CPLAY_META["$key"]="$val"
            elif [[ "$line" =~ ^duration=(.*)$ ]]; then
                local raw_dur="${BASH_REMATCH[1]}"
                CPLAY_META[duration]=$(cplay_format_duration "$raw_dur")
            fi
        done < <(ffprobe -v error -show_entries format_tags=title,artist,album,genre,date -show_entries format=duration -of default=noprint_wrappers=1 "$filepath" 2>/dev/null)
    fi

    # Try to extract cover art
    if command -v ffmpeg >/dev/null 2>&1; then
        local hash
        hash=$(echo -n "$filepath" | md5sum | cut -d' ' -f1)
        local art_path="$CPLAY_META_DIR/${hash}.png"
        if [[ -f "$art_path" ]]; then
            CPLAY_META_ART="$art_path"
        else
            if ffmpeg -y -i "$filepath" -an -vcodec copy "$art_path" >/dev/null 2>&1; then
                CPLAY_META_ART="$art_path"
                chmod 644 "$art_path" 2>/dev/null || true
            else
                # Fallback conversion if copy fails (e.g. scale and convert to png)
                if ffmpeg -y -i "$filepath" -an -vf "scale=300:-1" -f image2 "$art_path" >/dev/null 2>&1; then
                    CPLAY_META_ART="$art_path"
                    chmod 644 "$art_path" 2>/dev/null || true
                fi
            fi
        fi
    fi
}
