#!/usr/bin/env bash

# --- cplay Interactive TUI Player ---

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
    echo -e "  [${c}1${r}] Add & Play Track   |  [${c}2${r}] Add Music Source "
    echo -e "  [${c}l${r}] View Source Stats  |  [${c}Ctrl + Shift + C${r}] Exit"
    echo -e "${y}=================================================${r}"
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

tui_draw_queue() {
    clear
    echo "=== cplay Playlist Queue ==="
    if (( ${#CPLAY_QUEUE[@]} == 0 )); then
        echo "  Queue is empty."
    else
        for idx in "${!CPLAY_QUEUE[@]}"; do
            if (( idx == CPLAY_CURRENT_INDEX )); then
                echo "  > [$idx] ${CPLAY_QUEUE[$idx]}"
            else
                echo "    [$idx] ${CPLAY_QUEUE[$idx]}"
            fi
        done
    fi
    echo "============================"
    echo "  Press any key to return to main menu..."
}

tui_scan_recursive() {
    local target="$1"
    local indent="$2"
    
    for item in "$target"/*; do
        [[ -e "$item" ]] || continue
        local base
        base=$(basename "$item")
        
        if [[ -d "$item" ]]; then
            echo "${indent}[directory] $base"
            # Recursively scan the subdirectory with an increased indent
            tui_scan_recursive "$item" "  $indent"
        elif [[ -f "$item" ]]; then
            echo "${indent}[file] $base"
        else
            echo "${indent}[unknown] $base"
        fi
    done
}

# Build flat component list from source directories
# For folders, we track if they are expanded via a local map/associative array.
# Each component path will map to metadata: indent_level|type|name|is_expanded
# We'll use:
#   `CPLAY_STATS_ITEMS` - ordered array of item paths.
#   `CPLAY_STATS_META` - associative array of path -> "indent_level|type|name|parent_path"
#   `CPLAY_STATS_EXPANDED` - associative array of path -> "true" or "false"
# Sorting: `CPLAY_STATS_SORT_DIR` - "asc" or "desc" or "none"

declare -g -a CPLAY_STATS_ITEMS=()
declare -g -A CPLAY_STATS_META=()
declare -g -A CPLAY_STATS_EXPANDED=()
declare -g CPLAY_STATS_SORT_DIR="asc"
declare -g -i CPLAY_STATS_SELECT_IDX=0
declare -g -i CPLAY_STATS_SCROLL_OFFSET=0

tui_collect_items() {
    CPLAY_STATS_ITEMS=()
    # Build list of active root sources, optionally sorted
    local -a roots=()
    for root in "${!CPLAY_SOURCES[@]}"; do
        if [[ -d "$root" ]]; then
            roots+=("$root")
        fi
    done

    # Sort roots
    if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
        IFS=$'\n' roots=($(sort <<<"${roots[*]}")); unset IFS
    elif [[ "$CPLAY_STATS_SORT_DIR" == "desc" ]]; then
        IFS=$'\n' roots=($(sort -r <<<"${roots[*]}")); unset IFS
    fi

    # Recursively traverse each root and add to items list if parent is expanded
    for root in "${roots[@]}"; do
        # Root folder metadata
        CPLAY_STATS_META["$root"]="0|directory|$(basename "$root")|"
        CPLAY_STATS_ITEMS+=("$root")
        
        if [[ "${CPLAY_STATS_EXPANDED["$root"]}" == "true" ]]; then
            tui_collect_subdir_items "$root" 1
        fi
    done
}

tui_collect_subdir_items() {
    local parent="$1"
    local -i indent=$2
    local -a contents=()
    
    for item in "$parent"/*; do
        [[ -e "$item" ]] || continue
        contents+=("$item")
    done

    # Sort contents
    if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
        IFS=$'\n' contents=($(sort <<<"${contents[*]}")); unset IFS
    elif [[ "$CPLAY_STATS_SORT_DIR" == "desc" ]]; then
        IFS=$'\n' contents=($(sort -r <<<"${contents[*]}")); unset IFS
    fi

    for item in "${contents[@]}"; do
        local type="unknown"
        if [[ -d "$item" ]]; then
            type="directory"
        elif [[ -f "$item" ]]; then
            type="file"
        fi
        
        CPLAY_STATS_META["$item"]="$indent|$type|$(basename "$item")|$parent"
        CPLAY_STATS_ITEMS+=("$item")
        
        if [[ "$type" == "directory" && "${CPLAY_STATS_EXPANDED["$item"]}" == "true" ]]; then
            tui_collect_subdir_items "$item" $((indent + 1))
        fi
    done
}

tui_get_queue_status() {
    local path="$1"
    local type="$2"

    if [[ "$type" == "file" ]]; then
        # Check if file path is in the queue
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$path" ]]; then
                echo "(*)"
                return
            fi
        done
        echo "( )"
        return
    fi

    # For directory, recursively gather all files
    local -a files=()
    tui_gather_files() {
        local dir="$1"
        for item in "$dir"/*; do
            [[ -e "$item" ]] || continue
            if [[ -f "$item" ]]; then
                files+=("$item")
            elif [[ -d "$item" ]]; then
                tui_gather_files "$item"
            fi
        done
    }
    tui_gather_files "$path"

    local total=${#files[@]}
    if (( total == 0 )); then
        echo "( )"
        return
    fi

    local matched=0
    for f in "${files[@]}"; do
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$f" ]]; then
                ((matched++))
                break
            fi
        done
    done

    if (( matched == 0 )); then
        echo "( )"
    elif (( matched == total )); then
        echo "(*)"
    else
        echo "(-)"
    fi
}

tui_toggle_queue() {
    local path="$1"
    local type="$2"

    local -a files=()
    if [[ "$type" == "file" ]]; then
        files+=("$path")
    else
        tui_gather_files() {
            local dir="$1"
            for item in "$dir"/*; do
                [[ -e "$item" ]] || continue
                if [[ -f "$item" ]]; then
                    files+=("$item")
                elif [[ -d "$item" ]]; then
                    tui_gather_files "$item"
                fi
            done
        }
        tui_gather_files "$path"
    fi

    # Determine if all of them are already in the queue
    local all_queued=true
    for f in "${files[@]}"; do
        local found=false
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$f" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            all_queued=false
            break
        fi
    done

    local q_was_empty=false
    if (( ${#CPLAY_QUEUE[@]} == 0 )); then
        q_was_empty=true
    fi

    if [[ "$all_queued" == "true" ]]; then
        # Remove all from queue
        local -a new_queue=()
        for item in "${CPLAY_QUEUE[@]}"; do
            local keep=true
            for f in "${files[@]}"; do
                if [[ "$item" == "$f" ]]; then
                    keep=false
                    break
                fi
            done
            if [[ "$keep" == "true" ]]; then
                new_queue+=("$item")
            fi
        done
        CPLAY_QUEUE=("${new_queue[@]}")
    else
        # Add missing ones to queue
        for f in "${files[@]}"; do
            local found=false
            for item in "${CPLAY_QUEUE[@]}"; do
                if [[ "$item" == "$f" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                CPLAY_QUEUE+=("$f")
            fi
        done
    fi

    # Auto-play if queue went from empty to containing tracks
    if [[ "$q_was_empty" == "true" && ${#CPLAY_QUEUE[@]} -gt 0 ]]; then
        CPLAY_CURRENT_INDEX=0
        cplay_play "${CPLAY_QUEUE[0]}"
    fi
}

tui_scan_recursive() {
    local target="$1"
    local indent="$2"
    
    for item in "$target"/*; do
        [[ -e "$item" ]] || continue
        local base="${item##*/}"
        
        if [[ -d "$item" ]]; then
            echo "${indent}[directory] $base"
            tui_scan_recursive "$item" "  $indent"
        elif [[ -f "$item" ]]; then
            echo "${indent}[file] $base"
        else
            echo "${indent}[unknown] $base"
        fi
    done
}

# Render Maps and Arrays
declare -g -a CPLAY_STATS_ITEMS=()
declare -g -A CPLAY_STATS_META=()
declare -g -A CPLAY_STATS_EXPANDED=()
declare -g CPLAY_STATS_SORT_DIR="asc"
declare -g -i CPLAY_STATS_SELECT_IDX=0
declare -g -i CPLAY_STATS_SCROLL_OFFSET=0

# Interactive Queue Selection State
declare -g -i CPLAY_QUEUE_SELECT_IDX=0
declare -g -i CPLAY_QUEUE_SCROLL_OFFSET=0

tui_collect_items() {
    CPLAY_STATS_ITEMS=()
    local -a roots=()
    for root in "${!CPLAY_SOURCES[@]}"; do
        if [[ -d "$root" ]]; then
            roots+=("$root")
        fi
    done

    # Sort roots in-process using sort command
    if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
        IFS=$'\n' roots=($(sort <<<"${roots[*]}")); unset IFS
    elif [[ "$CPLAY_STATS_SORT_DIR" == "desc" ]]; then
        IFS=$'\n' roots=($(sort -r <<<"${roots[*]}")); unset IFS
    fi

    for root in "${roots[@]}"; do
        CPLAY_STATS_META["$root"]="0|directory|${root##*/}|"
        CPLAY_STATS_ITEMS+=("$root")
        
        if [[ "${CPLAY_STATS_EXPANDED["$root"]}" == "true" ]]; then
            tui_collect_subdir_items "$root" 1
        fi
    done
}

tui_collect_subdir_items() {
    local parent="$1"
    local -i indent=$2
    local -a contents=()
    
    for item in "$parent"/*; do
        [[ -e "$item" ]] || continue
        contents+=("$item")
    done

    if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
        IFS=$'\n' contents=($(sort <<<"${contents[*]}")); unset IFS
    elif [[ "$CPLAY_STATS_SORT_DIR" == "desc" ]]; then
        IFS=$'\n' contents=($(sort -r <<<"${contents[*]}")); unset IFS
    fi

    for item in "${contents[@]}"; do
        local type="unknown"
        if [[ -d "$item" ]]; then
            type="directory"
        elif [[ -f "$item" ]]; then
            type="file"
        fi
        
        CPLAY_STATS_META["$item"]="$indent|$type|${item##*/}|$parent"
        CPLAY_STATS_ITEMS+=("$item")
        
        if [[ "$type" == "directory" && "${CPLAY_STATS_EXPANDED["$item"]}" == "true" ]]; then
            tui_collect_subdir_items "$item" $((indent + 1))
        fi
    done
}

tui_get_queue_status() {
    local path="$1"
    local type="$2"

    if [[ "$type" == "file" ]]; then
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$path" ]]; then
                echo "(*)"
                return
            fi
        done
        echo "( )"
        return
    fi

    local -a files=()
    tui_gather_files() {
        local dir="$1"
        for item in "$dir"/*; do
            [[ -e "$item" ]] || continue
            if [[ -f "$item" ]]; then
                files+=("$item")
            elif [[ -d "$item" ]]; then
                tui_gather_files "$item"
            fi
        done
    }
    tui_gather_files "$path"

    local total=${#files[@]}
    if (( total == 0 )); then
        echo "( )"
        return
    fi

    local matched=0
    for f in "${files[@]}"; do
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$f" ]]; then
                ((matched++))
                break
            fi
        done
    done

    if (( matched == 0 )); then
        echo "( )"
    elif (( matched == total )); then
        echo "(*)"
    else
        echo "(-)"
    fi
}

tui_toggle_queue() {
    local path="$1"
    local type="$2"

    local -a files=()
    if [[ "$type" == "file" ]]; then
        files+=("$path")
    else
        tui_gather_files() {
            local dir="$1"
            for item in "$dir"/*; do
                [[ -e "$item" ]] || continue
                if [[ -f "$item" ]]; then
                    files+=("$item")
                elif [[ -d "$item" ]]; then
                    tui_gather_files "$item"
                fi
            done
        }
        tui_gather_files "$path"
    fi

    local all_queued=true
    for f in "${files[@]}"; do
        local found=false
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$f" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            all_queued=false
            break
        fi
    done

    local q_was_empty=false
    if (( ${#CPLAY_QUEUE[@]} == 0 )); then
        q_was_empty=true
    fi

    if [[ "$all_queued" == "true" ]]; then
        local -a new_queue=()
        for item in "${CPLAY_QUEUE[@]}"; do
            local keep=true
            for f in "${files[@]}"; do
                if [[ "$item" == "$f" ]]; then
                    keep=false
                    break
                fi
            done
            if [[ "$keep" == "true" ]]; then
                new_queue+=("$item")
            fi
        done
        CPLAY_QUEUE=("${new_queue[@]}")
    else
        for f in "${files[@]}"; do
            local found=false
            for item in "${CPLAY_QUEUE[@]}"; do
                if [[ "$item" == "$f" ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                CPLAY_QUEUE+=("$f")
            fi
        done
    fi

    if [[ "$q_was_empty" == "true" && ${#CPLAY_QUEUE[@]} -gt 0 ]]; then
        CPLAY_CURRENT_INDEX=0
        cplay_play "${CPLAY_QUEUE[0]}"
    fi
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
        q_status=$(tui_get_queue_status "$path" "$type")

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
