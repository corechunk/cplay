#!/usr/bin/env bash

# --- cplay Interactive Menu UI ---

run_menu() {
    # Initialize the playback engine
    engine_init

    while true; do
        clear
        echo "============================================="
        echo "                 cplay MENU                  "
        echo "============================================="
        echo "  Active Engine : $ACTIVE_ENGINE"
        echo "  Status        : $(cplay_status)"
        echo "  Queue size    : ${#CPLAY_QUEUE[@]} tracks"
        if (( ${#CPLAY_QUEUE[@]} > 0 )); then
            echo "  Playing Track : ${CPLAY_QUEUE[$CPLAY_CURRENT_INDEX]}"
        fi
        echo "============================================="
        echo "  1. Add & Play a Track (File/URL)"
        echo "  2. Pause / Resume"
        echo "  3. Seek Forward (+10s)"
        echo "  4. Seek Backward (-10s)"
        echo "  5. Volume Up (+5%)"
        echo "  6. Volume Down (-5%)"
        echo "  7. View Queue / Playlist"
        echo "  n. Next Track"
        echo "  p. Previous Track"
        echo "  i. Info (Diagnostics & System Status)"
        echo "  x. Exit"
        echo "============================================="
        
        read -rp "  Select an option: " opt
        
        case "$opt" in
            1)
                read -rp "  Enter Track Filepath or URL: " track
                if [[ -n "$track" ]]; then
                    # Add to playlist array
                    CPLAY_QUEUE+=("$track")
                    CPLAY_CURRENT_INDEX=$(( ${#CPLAY_QUEUE[@]} - 1 ))
                    cplay_play "$track"
                fi
                ;;
            2)
                cplay_pause
                ;;
            3)
                cplay_seek "10"
                ;;
            4)
                cplay_seek "-10"
                ;;
            5)
                cplay_volume "5"
                ;;
            6)
                cplay_volume "-5"
                ;;
            7)
                clear
                echo "=== Queue List ==="
                if (( ${#CPLAY_QUEUE[@]} == 0 )); then
                    echo "  Queue is empty."
                else
                    for idx in "${!CPLAY_QUEUE[@]}"; do
                        if (( idx == CPLAY_CURRENT_INDEX )); then
                            echo "  > [$idx] ${CPLAY_QUEUE[$idx]} (current)"
                        else
                            echo "    [$idx] ${CPLAY_QUEUE[$idx]}"
                        fi
                    done
                fi
                echo "=================="
                read -rp "  Press Enter to return to menu..."
                ;;
            n|N)
                cplay_next
                ;;
            p|P)
                cplay_prev
                ;;
            i|I)
                clear
                echo "=== cplay Diagnostics & System Status ==="
                echo "  Active Engine   : $ACTIVE_ENGINE"
                echo "  MPV Status      : $(driver_mpv_status 2>/dev/null || echo 'not running')"
                echo "  Raw Player PID  : $RAW_PLAYER_PID"
                echo "  Raw Status      : $(driver_raw_status 2>/dev/null || echo 'not running')"
                echo "  Cava Status     : $CAVA_STATUS (PID: $CAVA_PID)"
                echo "  Queue Size      : ${#CPLAY_QUEUE[@]}"
                echo "  Current Index   : $CPLAY_CURRENT_INDEX"
                echo "========================================="
                read -rp "  Press Enter to return to menu..."
                ;;
            x|X)
                exit 0
                ;;
            *)
                echo "  Invalid option, try again."
                sleep 1
                ;;
        esac
    done
}
