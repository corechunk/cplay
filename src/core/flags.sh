#!/usr/bin/env bash

# --- Command Line Argument / Flag Parser ---

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-imports|-c)
                # Strict check imports and diagnostic test
                bl_import -v --strict info/diagnostics.sh
                bl_info_check
                exit 0
                ;;
            --version)
                if [[ "$CPLAY_VERBOSE" == "true" ]]; then
                    echo "cplay version: $VERSION"
                    echo "Build Date: $(date)"
                    echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
                else
                    echo "$VERSION"
                fi
                exit 0
                ;;
            --provider)
                echo "github.com/corechunk"
                exit 0
                ;;
            --identity)
                echo "corechunk/cplay"
                exit 0
                ;;
            --tui|-t)
                CPLAY_MODE="tui"
                shift
                ;;
            --menu)
                CPLAY_MODE="menu"
                shift
                ;;
            --cli)
                CPLAY_MODE="cli"
                shift
                ;;
            --help|-h)
                echo "cplay - Terminal Music Player"
                echo "Usage: cplay [options]"
                echo ""
                echo "Options:"
                echo "  -h, --help           Show this help message"
                echo "  -c, --check-imports  Run diagnostics check"
                echo "  --provider           Show developer provider information"
                echo "  --identity           Show official application identity"
                echo "  --menu               Launch in interactive menu mode"
                echo "  --cli                Launch in non-interactive CLI mode"
                echo "  -m, --mode [raw|mpv] Select playback engine (default: raw)"
                echo "  -v, --verbose        Enable verbose output during diagnostics/cleanup"
                echo "  -f, --folder DIR     Launch with specific music folder"
                echo "  -t, --tui            Launch in interactive TUI mode (default)"
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
