# --- cplay Entry Point ---

run_cli() {
    echo "cplay CLI mode: Non-interactive playback is not yet fully implemented."
    echo "Arguments: $*"
    exit 0
}

main(){
	init "$@"
	case "$CPLAY_MODE" in
		cli)  run_cli "$@" ;;
		tui)  run_tui ;;
		menu) run_menu ;;
		*)    run_tui ;; # Default
	esac
}
main "$@"

#for i in {1..100};do echo "$i";sleep 0.1; done | bl_progress_bar -l "deleting backgound forks()s" --start "#ff00ff" --end "#0000ff"