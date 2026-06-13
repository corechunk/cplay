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
    tui_draw_header

    while true; do
        if [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
            tput cup 8 0
            echo -ne "\r  Active Engine: \e[32m$ACTIVE_ENGINE\e[0m | Status: \e[34m$(cplay_status)\e[0m\e[K"
            if (( ${#CPLAY_QUEUE[@]} > 0 )); then
                tput cup 9 0
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
                fi
            fi
            continue
        fi

        case "$key" in
            "n"|"N")
                cplay_next
                if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                    tui_show_source_stats
                elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                    tui_draw_queue
                elif [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
                    tui_draw_header
                fi
                continue
                ;;
            "b"|"B")
                cplay_prev
                if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                    tui_show_source_stats
                elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                    tui_draw_queue
                elif [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
                    tui_draw_header
                fi
                continue
                ;;
            "m"|"M")
                cplay_mute
                if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                    tui_show_source_stats
                elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                    tui_draw_queue
                elif [[ "$CPLAY_CURRENT_PAGE" == "main" ]]; then
                    tui_draw_header
                fi
                continue
                ;;
            "1")
                stty "$CPLAY_OLD_STTY"
                tput cnorm
                clear
                echo "=== cplay TUI Add Track ==="
                read -rp "  Enter Track Filepath or URL: " track
                if [[ -n "$track" ]]; then
                    CPLAY_QUEUE+=("$track")
                    CPLAY_CURRENT_INDEX=$(( ${#CPLAY_QUEUE[@]} - 1 ))
                    cplay_play "$track"
                fi
                stty -icanon -echo -isig
                tput civis
                CPLAY_CURRENT_PAGE="main"
                tui_draw_header
                continue
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
                        echo "  [Success] Added source folder: $dir_path"
                    else
                        echo "  [Error] Path is not a valid directory: $dir_path"
                    fi
                    sleep 1.5
                fi
                stty -icanon -echo -isig
                tput civis
                CPLAY_CURRENT_PAGE="main"
                tui_draw_header
                continue
                ;;
            "i"|"I")
                CPLAY_CURRENT_PAGE="info"
                tui_draw_info
                continue
                ;;
            "q"|"Q")
                CPLAY_CURRENT_PAGE="queue"
                tui_draw_queue
                continue
                ;;
            "l"|"L")
                CPLAY_CURRENT_PAGE="stats"
                tui_show_source_stats
                continue
                ;;
            $'\x03')
                break
                ;;
        esac

        if [[ "$CPLAY_CURRENT_PAGE" != "main" ]]; then
            if [[ "$key" == " " || "$key" == "" || "$key" == $'\n' || "$key" == $'\r' ]]; then
                if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                    local target_path="${CPLAY_STATS_ITEMS[$CPLAY_STATS_SELECT_IDX]}"
                    local meta="${CPLAY_STATS_META["$target_path"]}"
                    IFS='|' read -r indent type name parent <<< "$meta"
                    tui_toggle_queue "$target_path" "$type"
                    tui_show_source_stats
                    continue
                elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                    if (( ${#CPLAY_QUEUE[@]} > 0 )); then
                        CPLAY_CURRENT_INDEX=$CPLAY_QUEUE_SELECT_IDX
                        cplay_play "${CPLAY_QUEUE[$CPLAY_CURRENT_INDEX]}"
                        tui_draw_queue
                    fi
                    continue
                fi
            fi

            if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                if [[ "$key" == $'\x13' || "$key" == "s" || "$key" == "S" ]]; then
                    if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
                        CPLAY_STATS_SORT_DIR="desc"
                    else
                        CPLAY_STATS_SORT_DIR="asc"
                    fi
                    tui_show_source_stats
                    continue
                fi
            fi

            if [[ "$key" == $'\x03' ]]; then
                CPLAY_CURRENT_PAGE="main"
                tui_draw_header
                continue
            fi

            if [[ "$key" == $'\e' ]]; then
                local next1=""
                local next2=""
                if ! read -rn1 -t 0.03 next1; then
                    CPLAY_CURRENT_PAGE="main"
                    tui_draw_header
                    continue
                fi
                
                if [[ "$next1" == "O" ]]; then
                    read -rn1 -t 0.05 next2
                    case "$next2" in
                        "P") CPLAY_CURRENT_PAGE="main"; tui_draw_header; continue ;;
                        "Q") CPLAY_CURRENT_PAGE="stats"; tui_show_source_stats; continue ;;
                        "R") CPLAY_CURRENT_PAGE="queue"; tui_draw_queue; continue ;;
                        "S") CPLAY_CURRENT_PAGE="info"; tui_draw_info; continue ;;
                    esac
                fi

                if [[ "$next1" == " " ]]; then
                    cplay_pause
                    if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                        tui_show_source_stats
                    elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                        tui_draw_queue
                    fi
                    continue
                elif [[ "$next1" == "[" ]]; then
                    read -rn1 -t 0.05 next2
                    
                    if [[ "$next2" == "1" ]]; then
                        local next3=""
                        local next4=""
                        read -rn1 -t 0.05 next3
                        read -rn1 -t 0.05 next4
                        if [[ "$next3" == "5" && "$next4" == "~" ]]; then
                            CPLAY_CURRENT_PAGE="help"
                            tui_draw_help
                            continue
                        elif [[ "$next3" == "1" && "$next4" == "~" ]]; then
                            CPLAY_CURRENT_PAGE="main"; tui_draw_header; continue
                        elif [[ "$next3" == "2" && "$next4" == "~" ]]; then
                            CPLAY_CURRENT_PAGE="stats"; tui_show_source_stats; continue
                        elif [[ "$next3" == "3" && "$next4" == "~" ]]; then
                            CPLAY_CURRENT_PAGE="queue"; tui_draw_queue; continue
                        elif [[ "$next3" == "4" && "$next4" == "~" ]]; then
                            CPLAY_CURRENT_PAGE="info"; tui_draw_info; continue
                        fi
                        
                        if [[ "$next3" == ";" ]]; then
                            local next5=""
                            local next6=""
                            read -rn1 -t 0.05 next5
                            read -rn1 -t 0.05 next6
                            if [[ "$next5" == "3" ]]; then
                                # Alt + Arrows
                                case "$next6" in
                                    "A") cplay_volume "5" ;;
                                    "B") cplay_volume "-5" ;;
                                    "C") cplay_seek "10" ;;
                                    "D") cplay_seek "-10" ;;
                                esac
                                if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                                    tui_show_source_stats
                                elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                                    tui_draw_queue
                                fi
                                continue
                            elif [[ "$next5" == "5" ]]; then
                                # Ctrl + Arrows
                                if [[ "$next6" == "C" ]]; then
                                    cplay_next
                                elif [[ "$next6" == "D" ]]; then
                                    cplay_prev
                                fi
                                if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                                    tui_show_source_stats
                                elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                                    tui_draw_queue
                                fi
                                continue
                            fi
                        fi
                    fi

                    # Plain arrows: Up='A', Down='B', Right='C', Left='D'
                    if [[ "$next2" == "A" ]]; then # Plain Arrow Up
                        if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                            if (( CPLAY_STATS_SELECT_IDX > 0 )); then
                                CPLAY_STATS_SELECT_IDX=$((CPLAY_STATS_SELECT_IDX - 1))
                            fi
                            tui_show_source_stats
                        elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                            if (( CPLAY_QUEUE_SELECT_IDX > 0 )); then
                                CPLAY_QUEUE_SELECT_IDX=$((CPLAY_QUEUE_SELECT_IDX - 1))
                            fi
                            tui_draw_queue
                        fi
                        continue
                    elif [[ "$next2" == "B" ]]; then # Plain Arrow Down
                        if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                            if (( CPLAY_STATS_SELECT_IDX < ${#CPLAY_STATS_ITEMS[@]} - 1 )); then
                                CPLAY_STATS_SELECT_IDX=$((CPLAY_STATS_SELECT_IDX + 1))
                            fi
                            tui_show_source_stats
                        elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                            if (( CPLAY_QUEUE_SELECT_IDX < ${#CPLAY_QUEUE[@]} - 1 )); then
                                CPLAY_QUEUE_SELECT_IDX=$((CPLAY_QUEUE_SELECT_IDX + 1))
                            fi
                            tui_draw_queue
                        fi
                        continue
                    elif [[ "$next2" == "C" ]]; then # Plain Arrow Right
                        if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                            local target_path="${CPLAY_STATS_ITEMS[$CPLAY_STATS_SELECT_IDX]}"
                            local meta="${CPLAY_STATS_META["$target_path"]}"
                            IFS='|' read -r indent type name parent <<< "$meta"
                            if [[ "$type" == "directory" ]]; then
                                CPLAY_STATS_EXPANDED["$target_path"]="true"
                            fi
                            tui_show_source_stats
                        fi
                        continue
                    elif [[ "$next2" == "D" ]]; then # Plain Arrow Left
                        if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                            local target_path="${CPLAY_STATS_ITEMS[$CPLAY_STATS_SELECT_IDX]}"
                            local meta="${CPLAY_STATS_META["$target_path"]}"
                            IFS='|' read -r indent type name parent <<< "$meta"
                            if [[ "$type" == "directory" ]]; then
                                CPLAY_STATS_EXPANDED["$target_path"]="false"
                            fi
                            tui_show_source_stats
                        fi
                        continue
                    fi
                elif [[ "$next1" == $'\e' ]]; then
                    # Alternative Alt+Arrow sequences (e.g. \e\e[A)
                    local next3=""
                    read -rn1 -t 0.05 next3
                    if [[ "$next3" == "[" ]]; then
                        local next4=""
                        read -rn1 -t 0.05 next4
                        case "$next4" in
                            "A") cplay_volume "5" ;;
                            "B") cplay_volume "-5" ;;
                            "C") cplay_seek "10" ;;
                            "D") cplay_seek "-10" ;;
                        esac
                        if [[ "$CPLAY_CURRENT_PAGE" == "stats" ]]; then
                            tui_show_source_stats
                        elif [[ "$CPLAY_CURRENT_PAGE" == "queue" ]]; then
                            tui_draw_queue
                        fi
                        continue
                    fi
                fi
            fi

            # Any other key on sub pages is ignored
            continue
        fi

        # 3. Standard Key Bindings (Only active in "main" page)
        case "$key" in
            " ") # Spacebar pause/play toggle globally on main page
                cplay_pause
                continue
                ;;
            $'\e') # Escape Sequence (Arrows, Ctrl+Arrows, F-keys) for main page
                local next1=""
                local next2=""
                read -rn1 -t 0.05 next1
                read -rn1 -t 0.05 next2
                if [[ "$next1" == "O" ]]; then
                    case "$next2" in
                        "P") CPLAY_CURRENT_PAGE="main"; tui_draw_header; continue ;;
                        "Q") CPLAY_CURRENT_PAGE="stats"; tui_show_source_stats; continue ;;
                        "R") CPLAY_CURRENT_PAGE="queue"; tui_draw_queue; continue ;;
                        "S") CPLAY_CURRENT_PAGE="info"; tui_draw_info; continue ;;
                    esac
                elif [[ "$next1" == "[" ]]; then
                    if [[ "$next2" == "A" ]]; then # Up Arrow
                        cplay_volume "5"
                    elif [[ "$next2" == "B" ]]; then # Down Arrow
                        cplay_volume "-5"
                    elif [[ "$next2" == "C" ]]; then # Right Arrow
                        cplay_seek "10"
                    elif [[ "$next2" == "D" ]]; then # Left Arrow
                        cplay_seek "-10"
                    elif [[ "$next2" == "1" ]]; then
                        local next3=""
                        local next4=""
                        read -rn1 -t 0.05 next3
                        read -rn1 -t 0.05 next4
                        if [[ "$next3" == "5" && "$next4" == "~" ]]; then
                            CPLAY_CURRENT_PAGE="help"
                            tui_draw_help
                            continue
                        elif [[ "$next3" == ";" ]]; then
                            local next5=""
                            local next6=""
                            read -rn1 -t 0.05 next5
                            read -rn1 -t 0.05 next6
                            if [[ "$next5" == "5" ]]; then
                                if [[ "$next6" == "C" ]]; then
                                    cplay_next
                                    tui_draw_header
                                elif [[ "$next6" == "D" ]]; then
                                    cplay_prev
                                    tui_draw_header
                                fi
                            fi
                        fi
                    fi
                fi
                ;;
        esac
    done

    # Restore terminal settings on exit
    stty "$CPLAY_OLD_STTY"
    tput cnorm
    clear
    exit 0
}
