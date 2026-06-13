# flag parsing here
# def no flag to menu exec ....

main(){
	init "$@"
	if [[ "$CPLAY_TUI_MODE" == "true" ]]; then
		run_tui
	else
		run_menu
	fi
}
main "$@"

#for i in {1..100};do echo "$i";sleep 0.1; done | bl_progress_bar -l "deleting backgound forks()s" --start "#ff00ff" --end "#0000ff"