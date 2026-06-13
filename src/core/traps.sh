init(){
	parse_flags "$@"
	mkdir -p "$TMP"
	echo init

	#for i in {1..50};do
	#	while true;do
	#		echo "sleeping for ${i} seconds"
	#		sleep $i
	#	done &
	#	bl_pid_store "$i. idle printer" $!
	#done

}

deinit(){
	# Restore original terminal settings immediately before cleaning up
	if [[ -n "$CPLAY_OLD_STTY" ]]; then
		stty "$CPLAY_OLD_STTY" 2>/dev/null
	else
		stty sane 2>/dev/null
	fi
	tput cnorm 2>/dev/null

	#echo deinit
	trap - EXIT INT TERM

	local -a pids_keys=("${!BL_PIDS[@]}")
	local -i total_pids=${#pids_keys[@]}
	local -i total_steps=$(( total_pids + 2 ))
	local -i idx=1

	local pb_opts=("-l" "Performing Full Cleanup")
	if [[ "$CPLAY_VERBOSE" == "true" ]]; then
		pb_opts+=("--status" "--log")
	fi

	(
		emit_step() {
			local label="$1"
			local percent=$(( idx * 100 / total_steps ))
			if [[ "$CPLAY_VERBOSE" == "true" ]]; then
				echo "M:$label"
				echo "L:Completed step $idx/$total_steps: $label"
				echo "P:$percent"
			else
				echo "$percent"
			fi
			((idx++))
			sleep 0.1
		}

		# 1. Kill background processes
		for key in "${pids_keys[@]}"; do
			local pid="${BL_PIDS[$key]}"
			if kill -0 "$pid" 2>/dev/null; then
				kill "$pid"
			fi
			emit_step "Killed background $key (PID: $pid)"
		done

		# 2. Clean up temporary files
		rm -rf "$TMP"
		emit_step "Deleted temp workspace $TMP"

		# 3. Reset terminal states
		#reset
		emit_step "Terminal configuration restored"

	) | bl_progress_bar "${pb_opts[@]}" --start "#ff00ff" --end "#0000ff"

	exit 0
}

trap deinit EXIT INT TERM
