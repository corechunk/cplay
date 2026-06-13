#!/usr/bin/env bash

# --- cplay Interactive TUI Player ---

run_tui() {
    engine_init

    local launch_dir="$HOME/Music"
    if [[ -n "$CPLAY_LAUNCH_FOLDER" && -d "$CPLAY_LAUNCH_FOLDER" ]]; then
        launch_dir="$CPLAY_LAUNCH_FOLDER"
    fi

    if [[ -d "$launch_dir" ]]; then
        CPLAY_SOURCES["$launch_dir"]="active"
    fi

    CPLAY_OLD_STTY=$(stty -g)
    stty -icanon -echo -isig
    tput civis

    CPLAY_CURRENT_PAGE="main"
    clear
    tui_draw_header

    while true; do
        if [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
            tput cup 9 0
            echo -ne "\r  Active Engine: \e[32m$ACTIVE_ENGINE\e[0m | Status: \e[34m$(cplay_status)\e[0m\e[K"
            if (( ${#CPLAY_QUEUE[@]} > 0 )); then
                tput cup 10 0
                local playing_name="${CPLAY_QUEUE[$CPLAY_CURRENT_INDEX]}"
                playing_name="${playing_name##*/}"
                echo -ne "\r  Playing [$((CPLAY_CURRENT_INDEX + 1))/${#CPLAY_QUEUE[@]}]: \e[36m${playing_name}\e[0m\e[K"
            fi
        fi

        local key=""
        if ! IFS= read -rn1 -t 0.2 key; then
            if ! kill -0 "$RAW_PLAYER_PID" 2>/dev/null; then
                if [[ "$RAW_PAUSE_STATE" == "false" && ${#CPLAY_QUEUE[@]} -gt 0 ]]; then
                    cplay_next
                    if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                        tui_show_source_stats
                    elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                        tui_draw_queue
                    elif [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
                        tui_draw_header
                    elif [[ "$CPLAY_CURRENT_PAGE" == "metadata" ]]; then
                        tui_draw_metadata
                    fi
                fi
            fi
            continue
        fi

        # Determine parsed action
        local action=""
        local arg=""

        if [[ "$key" == $'\e' ]]; then
            local seq=""
            local ch=""
            # Rapidly consume all buffered bytes of the escape sequence
            while IFS= read -rn1 -t 0.02 ch; do
                seq+="$ch"
            done
            
            if [[ -z "$seq" ]]; then
                action="escape"
            else
                case "$seq" in
                    "[A"|"OA") action="up" ;;
                    "[B"|"OB") action="down" ;;
                    "[C"|"OC") action="right" ;;
                    "[D"|"OD") action="left" ;;
                    "[1;5A") action="ctrl_up" ;;
                    "[1;5B") action="ctrl_down" ;;
                    "[1;5C") action="ctrl_right" ;;
                    "[1;5D") action="ctrl_left" ;;
                    "[1;3A"|$'\e[A') action="alt_up" ;;
                    "[1;3B"|$'\e[B') action="alt_down" ;;
                    "[1;3C"|$'\e[C') action="alt_right" ;;
                    "[1;3D"|$'\e[D') action="alt_left" ;;
                    "[11~"|"OP") action="f1" ;;
                    "[12~"|"OQ") action="f2" ;;
                    "[13~"|"OR") action="f3" ;;
                    "[14~"|"OS") action="f4" ;;
                    "[15~") action="f5" ;;
                    "[17~") action="f6" ;;
                    "[18~") action="f7" ;;
                    "[19~") action="f8" ;;
                    "[20~") action="f9" ;;
                    "[67;6u"|"[99;6u") action="ctrl_shift_c" ;;
                    *) action="unknown" ;;
                esac
            fi
        elif [[ "$key" == $'\x03' ]]; then
            action="ctrl_c"
        elif [[ "$key" == " " ]]; then
            action="space"
        elif [[ "$key" == "" || "$key" == $'\n' || "$key" == $'\r' ]]; then
            action="enter"
        else
            action="key"
            arg="$key"
        fi

        # 1. Global Complete Exit
        if [[ "$action" == "ctrl_shift_c" ]]; then
            break
        fi

        # 2. Global Return to Main Menu
        if [[ "$action" == "ctrl_c" || "$action" == "escape" ]]; then
            if [[ "$CPLAY_CURRENT_PAGE" != "main" ]]; then
                if [[ "$CPLAY_CURRENT_PAGE" == "metadata" ]]; then tui_clear_metadata_art; fi
                CPLAY_CURRENT_PAGE="main"
                clear
                tui_draw_header
            fi
            continue
        fi

        # 3. Global Page Switching via F-Keys
        if [[ "$action" == "f"* ]]; then
            if [[ "$CPLAY_CURRENT_PAGE" == "metadata" ]]; then tui_clear_metadata_art; fi
            case "$action" in
                "f1") CPLAY_CURRENT_PAGE="main"; clear; tui_draw_header ;;
                "f2") CPLAY_CURRENT_PAGE="stats"; clear; tui_show_source_stats ;;
                "f3") CPLAY_CURRENT_PAGE="queue"; clear; tui_draw_queue ;;
                "f4") CPLAY_CURRENT_PAGE="info"; clear; tui_draw_info ;;
                "f5") CPLAY_CURRENT_PAGE="metadata"; clear; tui_draw_metadata ;;
            esac
            continue
        fi

        # 4. Global Playback Controls (Always run unless handled by specific subpage below)
        local is_global_playback="false"
        case "$action" in
            "ctrl_right") cplay_next; is_global_playback="true" ;;
            "ctrl_left")  cplay_prev; is_global_playback="true" ;;
            "alt_up")     cplay_volume "5"; is_global_playback="true" ;;
            "alt_down")   cplay_volume "-5"; is_global_playback="true" ;;
            "alt_right")  cplay_seek "10"; is_global_playback="true" ;;
            "alt_left")   cplay_seek "-10"; is_global_playback="true" ;;
            "key")
                case "$arg" in
                    "n"|"N") cplay_next; is_global_playback="true" ;;
                    "b"|"B") cplay_prev; is_global_playback="true" ;;
                    "m"|"M") cplay_mute; is_global_playback="true" ;;
                esac
                ;;
        esac

        if [[ "$is_global_playback" == "true" ]]; then
            if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then tui_show_source_stats;
            elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then tui_draw_queue;
            elif [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then tui_draw_header;
            elif [[ "$CPLAY_CURRENT_PAGE" == "metadata" ]]; then tui_draw_metadata; fi
            continue
        fi

        # 5. Page-specific handlers
        if [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
            case "$action" in
                "space")
                    cplay_pause
                    continue
                    ;;
                "up")
                    cplay_volume "5"
                    continue
                    ;;
                "down")
                    cplay_volume "-5"
                    continue
                    ;;
                "right")
                    cplay_seek "10"
                    continue
                    ;;
                "left")
                    cplay_seek "-10"
                    continue
                    ;;
                "key")
                    case "$arg" in
                        "1")
                            stty "$CPLAY_OLD_STTY"
                            tput cnorm
                            clear
                            echo "=== cplay TUI Add Track ==="
                            read -rp "  Enter Track Filepath or URL: " track
                            if [[ -n "$track" ]]; then
                                if [[ -f "$track" || "$track" =~ ^https?:// ]]; then
                                    CPLAY_QUEUE+=("$track")
                                    CPLAY_CURRENT_INDEX=$(( ${#CPLAY_QUEUE[@]} - 1 ))
                                    cplay_play "$track"
                                else
                                    echo "  [Error] Invalid file or URL. Action cancelled."
                                    sleep 1.5
                                fi
                            fi
                            stty -icanon -echo -isig
                            tput civis
                            CPLAY_CURRENT_PAGE="main"
                            clear
                            tui_draw_header
                            ;;
                        "2")
                            stty "$CPLAY_OLD_STTY"
                            tput cnorm
                            clear
                            echo "=== cplay TUI Add Music Source Directory ==="
                            read -rp "  Enter Directory Path: " dir_path
                            if [[ -n "$dir_path" ]]; then
                                if [[ -d "$dir_path" ]]; then
                                    CPLAY_SOURCES["$dir_path"]="active"
                                    CPLAY_STATS_DIRTY="true"
                                    echo "  [Success] Added source folder: $dir_path"
                                else
                                    echo "  [Error] Path is not a valid directory. Action cancelled: $dir_path"
                                fi
                                sleep 1.5
                            fi
                            stty -icanon -echo -isig
                            tput civis
                            CPLAY_CURRENT_PAGE="main"
                            clear
                            tui_draw_header
                            ;;
                        "i"|"I")
                            CPLAY_CURRENT_PAGE="info"
                            clear
                            tui_draw_info
                            ;;
                        "q"|"Q")
                            CPLAY_CURRENT_PAGE="queue"
                            clear
                            tui_draw_queue
                            ;;
                        "l"|"L")
                            CPLAY_CURRENT_PAGE="stats"
                            clear
                            tui_show_source_stats
                            ;;
                    esac
                    continue
                    ;;
            esac

        elif [[ "$CPLAY_CURRENT_PAGE" == "metadata" ]]; then
            case "$action" in
                "space")
                    cplay_pause
                    tui_draw_metadata
                    continue
                    ;;
                "up")
                    cplay_volume "5"
                    tui_draw_metadata
                    continue
                    ;;
                "down")
                    cplay_volume "-5"
                    tui_draw_metadata
                    continue
                    ;;
                "right")
                    cplay_seek "10"
                    tui_draw_metadata
                    continue
                    ;;
                "left")
                    cplay_seek "-10"
                    tui_draw_metadata
                    continue
                    ;;
            esac

        elif [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
            case "$action" in
                "space"|"enter")
                    local target_path="${CPLAY_STATS_ITEMS[$CPLAY_STATS_SELECT_IDX]}"
                    local meta="${CPLAY_STATS_META["$target_path"]}"
                    IFS='|' read -r indent type name parent <<< "$meta"
                    tui_toggle_queue "$target_path" "$type"
                    CPLAY_STATS_DIRTY="true"
                    tui_show_source_stats
                    continue
                    ;;
                "up")
                    if (( CPLAY_STATS_SELECT_IDX > 0 )); then
                        CPLAY_STATS_SELECT_IDX=$((CPLAY_STATS_SELECT_IDX - 1))
                    fi
                    tui_show_source_stats
                    continue
                    ;;
                "down")
                    if (( CPLAY_STATS_SELECT_IDX < ${#CPLAY_STATS_ITEMS[@]} - 1 )); then
                        CPLAY_STATS_SELECT_IDX=$((CPLAY_STATS_SELECT_IDX + 1))
                    fi
                    tui_show_source_stats
                    continue
                    ;;
                "right")
                    local target_path="${CPLAY_STATS_ITEMS[$CPLAY_STATS_SELECT_IDX]}"
                    local meta="${CPLAY_STATS_META["$target_path"]}"
                    IFS='|' read -r indent type name parent <<< "$meta"
                    if [[ "$type" == "directory" ]]; then
                        CPLAY_STATS_EXPANDED["$target_path"]="true"
                        CPLAY_STATS_DIRTY="true"
                    fi
                    tui_show_source_stats
                    continue
                    ;;
                "left")
                    local target_path="${CPLAY_STATS_ITEMS[$CPLAY_STATS_SELECT_IDX]}"
                    local meta="${CPLAY_STATS_META["$target_path"]}"
                    IFS='|' read -r indent type name parent <<< "$meta"
                    if [[ "$type" == "directory" ]]; then
                        CPLAY_STATS_EXPANDED["$target_path"]="false"
                        CPLAY_STATS_DIRTY="true"
                    fi
                    tui_show_source_stats
                    continue
                    ;;
                "key")
                    if [[ "$arg" == "s" || "$arg" == "S" ]]; then
                        if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
                            CPLAY_STATS_SORT_DIR="desc"
                        else
                            CPLAY_STATS_SORT_DIR="asc"
                        fi
                        CPLAY_STATS_DIRTY="true"
                        tui_show_source_stats
                    fi
                    continue
                    ;;
            esac

        elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
            case "$action" in
                "space"|"enter")
                    if (( ${#CPLAY_QUEUE[@]} > 0 )); then
                        CPLAY_CURRENT_INDEX=$CPLAY_QUEUE_SELECT_IDX
                        cplay_play "${CPLAY_QUEUE[$CPLAY_CURRENT_INDEX]}"
                        tui_draw_queue
                    fi
                    continue
                    ;;
                "up")
                    if (( CPLAY_QUEUE_SELECT_IDX > 0 )); then
                        CPLAY_QUEUE_SELECT_IDX=$((CPLAY_QUEUE_SELECT_IDX - 1))
                    fi
                    tui_draw_queue
                    continue
                    ;;
                "down")
                    if (( CPLAY_QUEUE_SELECT_IDX < ${#CPLAY_QUEUE[@]} - 1 )); then
                        CPLAY_QUEUE_SELECT_IDX=$((CPLAY_QUEUE_SELECT_IDX + 1))
                    fi
                    tui_draw_queue
                    continue
                    ;;
            esac
        fi
    done

    # Restore terminal settings on exit
    stty "$CPLAY_OLD_STTY"
    tput cnorm
    clear
    exit 0
}
