#!/usr/bin/env bash

# Render Maps and Arrays
declare -g -a CPLAY_STATS_ITEMS=()
declare -g -A CPLAY_STATS_META=()
declare -g -A CPLAY_STATS_EXPANDED=()
declare -g CPLAY_STATS_SORT_DIR="asc"
declare -g -i CPLAY_STATS_SELECT_IDX=0
declare -g -i CPLAY_STATS_SCROLL_OFFSET=0
# Dirty flag: set true whenever tree structure changes (fold/unfold, source add).
# tui_collect_items is a no-op when false, saving a full tree walk on cursor moves.
declare -g CPLAY_STATS_DIRTY="true"

# Interactive Queue Selection State
declare -g -i CPLAY_QUEUE_SELECT_IDX=0
declare -g -i CPLAY_QUEUE_SCROLL_OFFSET=0

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

tui_collect_items() {
    # Skip rebuild if tree structure has not changed (e.g. plain cursor move).
    [[ "$CPLAY_STATS_DIRTY" == "true" ]] || return
    CPLAY_STATS_DIRTY="false"

    CPLAY_STATS_ITEMS=()
    # Build list of active root sources, optionally sorted
    local -a roots=()
    for root in "${!CPLAY_SOURCES[@]}"; do
        if [[ -d "$root" ]]; then
            roots+=("$root")
        fi
    done

    # Sort roots once (single subprocess, only at root level)
    if [[ "$CPLAY_STATS_SORT_DIR" == "asc" ]]; then
        IFS=$'\n' roots=($(sort <<<"${roots[*]}")); unset IFS
    elif [[ "$CPLAY_STATS_SORT_DIR" == "desc" ]]; then
        IFS=$'\n' roots=($(sort -r <<<"${roots[*]}")); unset IFS
    fi

    # Recursively traverse each root and add to items list if parent is expanded
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

    # Glob expands in locale-sorted order on most Linux filesystems.
    # No sort subprocess needed per directory — saves N forks on deep trees.
    for item in "$parent"/*; do
        [[ -e "$item" ]] || continue
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

# tui_get_queue_status PATH TYPE RESULT_VAR
# Writes result into RESULT_VAR via nameref — no subshell, no fork.
tui_get_queue_status() {
    local path="$1"
    local type="$2"
    local -n _qs_result="$3"

    if [[ "$type" == "file" ]]; then
        for item in "${CPLAY_QUEUE[@]}"; do
            if [[ "$item" == "$path" ]]; then
                _qs_result="(*)"
                return
            fi
        done
        _qs_result="( )"
        return
    fi

    # For a directory: walk its files and compare against queue
    local -a files=()
    _tui_gather_files_into() {
        local dir="$1"
        for item in "$dir"/*; do
            [[ -e "$item" ]] || continue
            if [[ -f "$item" ]]; then
                files+=("$item")
            elif [[ -d "$item" ]]; then
                _tui_gather_files_into "$item"
            fi
        done
    }
    _tui_gather_files_into "$path"

    local total=${#files[@]}
    if (( total == 0 )); then
        _qs_result="( )"
        return
    fi

    # Build an O(1) lookup set from the queue
    local -A _queue_set=()
    for item in "${CPLAY_QUEUE[@]}"; do
        _queue_set["$item"]=1
    done

    local matched=0
    for f in "${files[@]}"; do
        [[ -v _queue_set["$f"] ]] && (( matched++ ))
    done

    if (( matched == 0 )); then
        _qs_result="( )"
    elif (( matched == total )); then
        _qs_result="(*)"
    else
        _qs_result="(-)"
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
