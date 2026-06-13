#!/usr/bin/env bash

# --- Command Line Argument / Flag Parser ---

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-imports|-c)
                # Strict check imports and diagnostic test
                bl_import -v --strict info/diagnostics.sh
                bl_info_check
				read
                exit 0
                ;;
            --help|-h)
                echo "cplay - Terminal Music Player"
                echo "Usage: cplay [options]"
                echo ""
                echo "Options:"
                echo "  -h, --help           Show this help message"
                echo "  -c, --check-imports  Run diagnostics check"
                echo "  -m, --mode [raw|mpv] Select playback engine (default: raw)"
                echo "  -v, --verbose        Enable verbose output during diagnostics/cleanup"
                echo "  -f, --folder DIR     Launch with specific music folder"
                echo "  -t, --tui            Launch in interactive raw keyboard TUI mode"
                read
                exit 0
                ;;
            --mode|-m)
                if [[ "$2" == "mpv" || "$2" == "raw" ]]; then
                    ACTIVE_ENGINE="$2"
                    shift 2
                else
                    echo "Error: Unknown mode '$2'. Valid modes: raw, mpv" >&2
                    exit 1
                fi
                ;;
            --verbose|-v)
                CPLAY_VERBOSE="true"
                shift
                ;;
            --tui|-t)
                CPLAY_TUI_MODE="true"
                shift
                ;;
            --folder|-f)
                if [[ -d "$2" ]]; then
                    CPLAY_LAUNCH_FOLDER="$2"
                else
                    echo "Error: Launch folder '$2' is not a valid directory." >&2
                    exit 1
                fi
                shift 2
                ;;
            *)
                # Shift to parse next arguments
                shift
                ;;
        esac
    done
}
