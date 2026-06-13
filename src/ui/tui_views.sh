#!/usr/bin/env bash

tui_draw_header() {
    clear
    # Sourced from core/colors.sh globally
    local y="${BL_YELLOW}"
    local c="${BL_SKY_BLUE}"
    local r="${BL_RESET}"
    
    echo -e "${y}=================================================${r}"
    echo -e "${y}            cplay INTERACTIVE TUI MODE           ${r}"
    echo -e "${y}=================================================${r}"
    echo -e "  [${c}Space${r}] Play/Pause  |  [${c}Arrows${r}] Volume & Seek  "
    echo -e "  [${c}n${r} / ${c}Ctrl+Right${r}] Next  |  [${c}b${r} / ${c}Ctrl+Left${r}] Prev "
    echo -e "  [${c}i${r}] Diagnostics Info   |  [${c}q${r}] View Playlist    "
    echo -e "  [${c}l${r}] View Source Stats  |  [${c}F5${r}] Track Metadata   "
    echo -e "  [${c}1${r}] Add & Play Track   |  [${c}2${r}] Add Music Source "
    echo -e "${y}=================================================${r}"
    echo -e "  Press [${c}Ctrl+Shift+C${r}] anywhere to completely exit."
}

tui_draw_info() {
    clear
    local y="${BL_YELLOW}"
    local g="${BL_GREEN}"
    local red="${BL_RED}"
    local c="${BL_SKY_BLUE}"
    local r="${BL_RESET}"
    
    # Fetch live statuses
    local mpv_raw
    mpv_raw=$(driver_mpv_status 2>/dev/null || echo "not running")
    local raw_raw
    raw_raw=$(driver_raw_status 2>/dev/null || echo "not running")
    
    # State-based colors
    local mpv_color="$red"
    if [[ "$mpv_raw" == "active" ]]; then
        mpv_color="$g"
    fi
    
    local raw_color="$red"
    if [[ "$raw_raw" == *"playing"* ]]; then
        raw_color="$g"
    elif [[ "$raw_raw" == *"paused"* ]]; then
        raw_color="$y"
    fi
    
    local cava_color="$red"
    if [[ "$CAVA_STATUS" == "active" ]]; then
        cava_color="$g"
    fi

    echo -e "${y}=== cplay Diagnostics & System Status ===${r}"
    echo -e "  Active Engine   : ${c}${ACTIVE_ENGINE}${r}"
    echo -e "  MPV Status      : ${mpv_color}${mpv_raw}${r}"
    echo -e "  Raw Player PID  : ${c}${RAW_PLAYER_PID}${r}"
    echo -e "  Raw Status      : ${raw_color}${raw_raw}${r}"
    echo -e "  Cava Status     : ${cava_color}${CAVA_STATUS}${r} (PID: ${c}${CAVA_PID}${r})"
    echo -e "  Queue Size      : ${c}${#CPLAY_QUEUE[@]}${r}"
    echo -e "  Current Index   : ${c}${CPLAY_CURRENT_INDEX}${r}"
    echo -e "${y}=========================================${r}"
    echo -e "  Press Esc or Ctrl+C to return to main menu..."
}

tui_show_source_stats() {
    tput cup 0 0
    tui_collect_items

    local num_items=${#CPLAY_STATS_ITEMS[@]}
    local max_lines=15
    
    local y="${BL_YELLOW}"
    local g="${BL_GREEN}"
    local c="${BL_SKY_BLUE}"
    local r="${BL_RESET}"
    # Sky Blue Background (106) with Black Text (30)
    local select_bg="\e[106m\e[30m"

    if (( CPLAY_STATS_SELECT_IDX < 0 )); then
        CPLAY_STATS_SELECT_IDX=0
    fi
    if (( num_items > 0 && CPLAY_STATS_SELECT_IDX >= num_items )); then
        CPLAY_STATS_SELECT_IDX=$((num_items - 1))
    fi

    if (( CPLAY_STATS_SELECT_IDX < CPLAY_STATS_SCROLL_OFFSET )); then
        CPLAY_STATS_SCROLL_OFFSET=$CPLAY_STATS_SELECT_IDX
    elif (( CPLAY_STATS_SELECT_IDX >= CPLAY_STATS_SCROLL_OFFSET + max_lines )); then
        CPLAY_STATS_SCROLL_OFFSET=$(( CPLAY_STATS_SELECT_IDX - max_lines + 1 ))
    fi

    local buf=""
    buf+="${y}=== Source Directories Stats Listing ===${r}\n"
    buf+="  [Arrow Up/Down] Select | [Arrow Left/Right] Fold/Unfold\n"
    buf+="  [Space/Enter] Toggle Queue | [Ctrl+S] Sort: $CPLAY_STATS_SORT_DIR\n"
    buf+="${y}=========================================${r}\n"

    if (( num_items == 0 )); then
        buf+="  No music source folders registered.\e[K\n"
        buf+="  (Press '2' in the main menu to add a source folder).\e[K\n"
        buf+="${y}=========================================${r}\e[K\n"
        buf+="  Press Esc or Ctrl+C to return to main menu...\e[K\n"
        printf "%b" "$buf"
        return
    fi

    local end_idx=$(( CPLAY_STATS_SCROLL_OFFSET + max_lines ))
    if (( end_idx > num_items )); then
        end_idx=$num_items
    fi

    for (( i=CPLAY_STATS_SCROLL_OFFSET; i<end_idx; i++ )); do
        local path="${CPLAY_STATS_ITEMS[$i]}"
        local meta="${CPLAY_STATS_META["$path"]}"
        
        IFS='|' read -r indent type name parent <<< "$meta"
        
        local indent_str=""
        for (( j=0; j<indent; j++ )); do
            indent_str="  $indent_str"
        done

        local prefix="  "
        if (( i == CPLAY_STATS_SELECT_IDX )); then
            prefix="> "
        fi

        local exp_indicator="     "
        local type_str=""
        if [[ "$type" == "directory" ]]; then
            if [[ "${CPLAY_STATS_EXPANDED["$path"]}" == "true" ]]; then
                exp_indicator="${g}[-]${r}  "
            else
                exp_indicator="${y}[+]${r}  "
            fi
            type_str="${y}[ DIR ]${r}"
        else
            type_str="${c}[FILE]${r} "
        fi

        local q_status
        tui_get_queue_status "$path" "$type" q_status

        local q_colored=""
        case "$q_status" in
            "(*)") q_colored="${g}(*)${r}" ;;
            "(-)") q_colored="${y}(-)${r}" ;;
            "( )") q_colored="( )" ;;
        esac

        if (( i == CPLAY_STATS_SELECT_IDX )); then
            local plain_exp="     "
            if [[ "$type" == "directory" ]]; then
                if [[ "${CPLAY_STATS_EXPANDED["$path"]}" == "true" ]]; then
                    plain_exp="[-]  "
                else
                    plain_exp="[+]  "
                fi
            fi
            local plain_type="[FILE] "
            if [[ "$type" == "directory" ]]; then
                plain_type="[ DIR ]"
            fi
            buf+="${select_bg}${prefix}${indent_str}${plain_exp}${plain_type} ${q_status} ${name}${r}\e[K\n"
        else
            buf+="${prefix}${indent_str}${exp_indicator}${type_str} ${q_colored} ${name}\e[K\n"
        fi
    done

    buf+="${y}=========================================${r}\e[K\n"
    buf+="  Item $(( CPLAY_STATS_SELECT_IDX + 1 )) of $num_items | Queue Size: ${#CPLAY_QUEUE[@]}\e[K\n"
    printf "%b" "$buf"
}

tui_draw_queue() {
    tput cup 0 0
    local num_items=${#CPLAY_QUEUE[@]}
    local max_lines=15
    local y="${BL_YELLOW}"
    local g="${BL_GREEN}"
    local c="${BL_SKY_BLUE}"
    local r="${BL_RESET}"
    local select_bg="\e[106m\e[30m"

    if (( CPLAY_QUEUE_SELECT_IDX < 0 )); then
        CPLAY_QUEUE_SELECT_IDX=0
    fi
    if (( num_items > 0 && CPLAY_QUEUE_SELECT_IDX >= num_items )); then
        CPLAY_QUEUE_SELECT_IDX=$((num_items - 1))
    fi

    if (( CPLAY_QUEUE_SELECT_IDX < CPLAY_QUEUE_SCROLL_OFFSET )); then
        CPLAY_QUEUE_SCROLL_OFFSET=$CPLAY_QUEUE_SELECT_IDX
    elif (( CPLAY_QUEUE_SELECT_IDX >= CPLAY_QUEUE_SCROLL_OFFSET + max_lines )); then
        CPLAY_QUEUE_SCROLL_OFFSET=$(( CPLAY_QUEUE_SELECT_IDX - max_lines + 1 ))
    fi

    local buf=""
    buf+="${y}=== cplay Playlist Queue ===${r}\n"
    buf+="  [Arrow Up/Down] Select Track | [Space/Enter] Play Selection\n"
    buf+="  [Esc / Ctrl+C] Back to Main Menu\n"
    buf+="${y}============================${r}\n"

    if (( num_items == 0 )); then
        buf+="  Queue is empty.\e[K\n"
    else
        local end_idx=$(( CPLAY_QUEUE_SCROLL_OFFSET + max_lines ))
        if (( end_idx > num_items )); then
            end_idx=$num_items
        fi

        for (( i=CPLAY_QUEUE_SCROLL_OFFSET; i<end_idx; i++ )); do
            local track_path="${CPLAY_QUEUE[$i]}"
            local base="${track_path##*/}"
            local play_indicator="  "
            local color_start=""
            local color_end=""
            
            if (( i == CPLAY_CURRENT_INDEX )); then
                play_indicator="* "
                color_start="${g}"
                color_end="${r}"
            fi

            if (( i == CPLAY_QUEUE_SELECT_IDX )); then
                buf+="${select_bg}${play_indicator}[$((i + 1))] ${base}${r}\e[K\n"
            else
                buf+="${play_indicator}${color_start}[$((i + 1))] ${base}${color_end}\e[K\n"
            fi
        done
    fi
    buf+="${y}============================${r}\e[K\n"
    buf+="  Item $(( CPLAY_QUEUE_SELECT_IDX + 1 )) of $num_items\e[K\n"
    printf "%b" "$buf"
}

tui_clear_metadata_art() {
    if [[ "$CPLAY_KITTY_SUPPORT" == "true" ]]; then
        kitty +kitten icat --clear
    fi
}

tui_draw_metadata() {
    clear
    local y="${BL_YELLOW}"
    local g="${BL_GREEN}"
    local c="${BL_SKY_BLUE}"
    local r="${BL_RESET}"

    echo -e "${y}=== Track Metadata Details (F5) ===${r}"
    echo -e "  Title      : ${g}${CPLAY_META[title]}${r}"
    echo -e "  Artist     : ${c}${CPLAY_META[artist]}${r}"
    echo -e "  Album      : ${c}${CPLAY_META[album]}${r}"
    echo -e "  Genre      : ${c}${CPLAY_META[genre]}${r}"
    echo -e "  Year/Date  : ${c}${CPLAY_META[date]}${r}"
    echo -e "  Duration   : ${c}${CPLAY_META[duration]}${r}"
    echo -e "  File Path  : ${c}${CPLAY_META[filepath]}${r}"
    echo -e "  Kitty API  : ${c}${CPLAY_KITTY_SUPPORT}${r}"
    echo -e "${y}=====================================${r}"
    echo -e "  Press Esc or Ctrl+C to return to main menu..."

    if [[ "$CPLAY_KITTY_SUPPORT" == "true" ]]; then
        if [[ -n "$CPLAY_META_ART" && -f "$CPLAY_META_ART" ]]; then
            # 30 cols × 15 rows, placed at col 2, row 12 (below the text block)
            kitty +kitten icat --transfer-mode=file --place 30x15@2x12 "$CPLAY_META_ART"
        else
            echo -e "  ${y}[ No Cover Art Found ]${r}"
        fi
    else
        echo -e "  \e[90m[ Kitty API Not Active ]\e[0m"
    fi
}
