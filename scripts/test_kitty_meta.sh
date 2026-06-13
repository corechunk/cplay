#!/usr/bin/env bash

# Test script to extract metadata and cover art from an audio file and display it in Kitty.

if [[ -z "$1" ]]; then
    echo "Usage: $0 <path_to_audio_file>"
    exit 1
fi

FILEPATH="$1"

if [[ ! -f "$FILEPATH" ]]; then
    echo "Error: File not found: $FILEPATH"
    exit 1
fi

# Detect Kitty
KITTY_SUPPORT="false"
if [[ "$TERM" == *"kitty"* || -n "$KITTY_WINDOW_ID" ]]; then
    KITTY_SUPPORT="true"
fi

echo "=== cplay Meta & Kitty icat Test ==="
echo "File: $FILEPATH"
echo "Kitty Support Detected: $KITTY_SUPPORT"
echo ""

# Extract text metadata using ffprobe
if command -v ffprobe >/dev/null 2>&1; then
    echo "--- Text Metadata ---"
    ffprobe -v error -show_entries format_tags=title,artist,album,genre,date -show_entries format=duration -of default=noprint_wrappers=1 "$FILEPATH"
    echo "---------------------"
else
    echo "[Warning] ffprobe not found. Cannot extract text metadata."
fi

# Extract cover art using ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
    ART_PATH="/tmp/cplay_test_cover.png"
    
    echo -e "\nExtracting cover art to $ART_PATH..."
    
    # Try raw copy first, fallback to scaling conversion
    if ffmpeg -y -i "$FILEPATH" -an -vcodec copy "$ART_PATH" >/dev/null 2>&1 || \
       ffmpeg -y -i "$FILEPATH" -an -vf "scale=300:-1" -f image2 "$ART_PATH" >/dev/null 2>&1; then
        
        echo "Cover art successfully extracted to: $ART_PATH"
        
        if [[ "$KITTY_SUPPORT" == "true" ]]; then
            echo -e "\nDisplaying cover art via Kitty icat..."
            
            # Print standard output/error to see if kitty complains
            if ! timeout 2 kitty +kitten icat --transfer-mode=file "$ART_PATH"; then
                echo "[Error] kitty icat command timed out or failed. This can happen if tmux intercepts the graphics protocol."
            fi
            echo ""
        else
            echo -e "\n[Notice] Terminal does not appear to be Kitty (TERM=$TERM). Skipping image render."
        fi
    else
        echo "No embedded cover art found in the file, or extraction failed."
    fi
else
    echo "[Warning] ffmpeg not found. Cannot extract cover art."
fi
