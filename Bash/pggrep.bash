# Add in .bashrc

function pggrep {
    local TARGET="SRC"
    local MODE="LOOSE"
    local FILES_WITH_MATCHES="0"
    local SOURCE_PATH="/home/benoit/git/world/postgres"
    local TARGET_PARM=""
    local MODE_PARM=""
    local FWM_PARM=""
    local SEARCH_STRING=""
    local OPTIND

    while getopts "t:m:f" option; do                                                
    case "${option}" in                                                         
         t) TARGET="${OPTARG}" ;;
	 m) MODE="${OPTARG}" ;;
	 f) FILES_WITH_MATCHES="1" ;;
	 *) echo "pggrep [-t TARGET] [-m MODE] [-l]"; return ;;
    esac                                                                        
    done
    shift $((OPTIND - 1))
    SEARCH_STRING="$*"

    case "$TARGET" in
         "SRC") TARGET_PARM="--include \"*.c\"  --include \"*.h\" --include \"README*\"" ;;
         "DOC") TARGET_PARM="--include \"*.sgml\" --include \"README*\"" ;;
	 *) echo "TARGET = [SRC|DOC]"; return ;;
    esac

    case "$MODE" in
         "STRICT") MODE_PARM="" ;;
	 "LOOSE") MODE_PARM="--ignore-case" ;;
	 *) echo "MODE = [LOOSE|STRICT]"; return ;;
    esac

    if [[ "$FILES_WITH_MATCHES" -eq "1" ]]; then
	FWM_PARM="--files-with-matches"
    fi

    eval "grep --recursive $FWM_PARM $MODE_PARM $TARGET_PARM \"$SEARCH_STRING\" \"$SOURCE_PATH\""
}

