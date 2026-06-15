#!/usr/bin/env sh
set -e

# --- Install settings & Binary paths ---
BIN_NAME="cplay"
VERSION_FILE_NAME="VERSION"
BIN_TARGET=""
INSTALL_MODE=""
repo_release_latest_download="https://github.com/corechunk/cplay/releases/latest/download"

# Dependency Categories (Format: cmd:min_version)
DEPS_REQUIRED="bash:4.0 ffmpeg:0.5 ffprobe:0.5" # for the software
DEPS_OPTIONAL="kitty:0.10.0 mpv:0.17.0 curl:7.80.0 magick:6.0" # for the software

# Source dirs
SRC_LOCAL="${0%/*}"
[ "$SRC_LOCAL" = "$0" ] && SRC_LOCAL="."
SRC_REMOTE="$repo_release_latest_download"

# Source file
SRC_FILE_LOCAL="$SRC_LOCAL/$BIN_NAME"
SRC_FILE_REMOTE="$repo_release_latest_download/$BIN_NAME"

# Version file locations
VERSION_FILE_LOCAL="$SRC_LOCAL/$VERSION_FILE_NAME"
VERSION_FILE_REMOTE="$repo_release_latest_download/$VERSION_FILE_NAME"

# OS Managed (FHS Standard)
BIN_OS_ROOT="/bin"
BIN_OS_USR="/usr/bin"

# Administrator/Third-Party
BIN_SYS="/usr/local/bin"
BIN_USR="$HOME/.local/bin"
BIN_OPT="/opt/cplay/bin"

# Temporary/Dev
BIN_TMP="$(mktemp -d)"
mkdir -p "$BIN_TMP/bin"
trap 'rm -rf "$BIN_TMP"' EXIT

# Fetched asset locations (used in Remote mode)
SRC_FILE_REMOTE_FETCHED="$BIN_TMP/$BIN_NAME"
VERSION_FILE_REMOTE_FETCHED="$BIN_TMP/$VERSION_FILE_NAME"

# --- Flag Parser ---
while [ "$#" -gt 0 ]; do
    case "$1" in
        --local) INSTALL_MODE="local" ;;
        --remote) INSTALL_MODE="remote" ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done
# --- Auto-Detection ---
if [ -z "$INSTALL_MODE" ]; then
    if [ -f "$0" ]; then
        INSTALL_MODE="local"
    else
        INSTALL_MODE="remote"
    fi
fi

# --- Phase 3: Resolution (The Bridge) ---
if [ "$INSTALL_MODE" = "local" ]; then
    SRC="$SRC_FILE_LOCAL"
    VERSION_SRC="$VERSION_FILE_LOCAL"
else
    # Remote mode: Fetch assets to temporary storage
    echo "Fetching remote assets..."
    
    # Ensure curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl is required to fetch remote assets."
        exit 1
    fi

    curl -fsSL "$VERSION_FILE_REMOTE" -o "$VERSION_FILE_REMOTE_FETCHED" || { echo "Error: Could not fetch version file."; exit 1; }
    curl -fsSL "$SRC_FILE_REMOTE" -o "$SRC_FILE_REMOTE_FETCHED" || { echo "Error: Could not fetch binary."; exit 1; }

    SRC="$SRC_FILE_REMOTE_FETCHED"
    VERSION_SRC="$VERSION_FILE_REMOTE_FETCHED"
fi

echo "Running in $INSTALL_MODE mode."
echo "Resolved Source: $SRC"

# --- Functions ---

# --- IFS Helpers ---
# Internal variables for IFS management
_del=$(printf '\n')
_old_del=""

IFS_use() {
    _old_del="$IFS"
    IFS="$_del"
}

IFS_rst() {
    IFS="$_old_del"
}

# Input: $1 (path to binary)
# Returns 0 if binary returns our identity, 1 otherwise
is_official_cplay() {
    [ ! -f "$1" ] && return 1
    # Check for footprint via flag
    "$1" --identity 2>/dev/null | grep -q "corechunk/cplay"
}

# Input: $1 (version 1), $2 (version 2)
# Output: "major", "minor", "patch", "hotfix", "downgrade", or "equal"
posix_version_compare() {
    v1="$1"; v2="$2"
    case "$v1" in v*|V*) v1="${v1#?}" ;; esac
    case "$v2" in v*|V*) v2="${v2#?}" ;; esac

    IFS='.'
    set -- $v1
    v1_a=${1:-0}; v1_b=${2:-0}; v1_c=${3:-0}; v1_d=${4:-0}
    set -- $v2
    v2_a=${1:-0}; v2_b=${2:-0}; v2_c=${3:-0}; v2_d=${4:-0}
    unset IFS

    if [ "$v1_a" -lt "$v2_a" ]; then echo "major"; return; fi
    if [ "$v1_a" -gt "$v2_a" ]; then echo "downgrade"; return; fi
    if [ "$v1_b" -lt "$v2_b" ]; then echo "minor"; return; fi
    if [ "$v1_b" -gt "$v2_b" ]; then echo "downgrade"; return; fi
    if [ "$v1_c" -lt "$v2_c" ]; then echo "patch"; return; fi
    if [ "$v1_c" -gt "$v2_c" ]; then echo "downgrade"; return; fi
    if [ "$v1_d" -lt "$v2_d" ]; then echo "hotfix"; return; fi
    if [ "$v1_d" -gt "$v2_d" ]; then echo "downgrade"; return; fi
    echo "equal"
}

# Input: $1 (command name)
# Output: Corresponding package name
get_package_name() {
    case "$1" in
        mpv) echo "mpv" ;;
        curl) echo "curl" ;;
        *) echo "$1" ;;
    esac
}

# Input: $1 (command name)
# Output: Version string
get_installed_version() {
    case "$1" in
        bash)    bash --version | head -n1 | cut -d' ' -f4 | cut -d'(' -f1 ;;
        mpv)     mpv --version 2>&1 | head -n1 | cut -d' ' -f2 ;;
        curl)    curl --version 2>&1 | head -n1 | cut -d' ' -f2 ;;
        ffmpeg)  ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3 ;;
        ffprobe) ffprobe -version 2>&1 | head -n1 | cut -d' ' -f3 ;;
        kitty)   kitty --version 2>&1 | head -n1 | cut -d' ' -f2 ;;
        magick)
            if command -v magick >/dev/null 2>&1; then
                magick -version | head -n1 | cut -d' ' -f3
            elif command -v convert >/dev/null 2>&1; then
                convert -version | head -n1 | cut -d' ' -f3
            else
                echo "0.0.0"
            fi
            ;;
        pw-cat)  pw-cat --version 2>&1 | head -n1 | cut -d' ' -f2 ;;
        pacat)   pacat --version 2>&1 | head -n1 | cut -d' ' -f2 ;;
        *)       echo "0.0.0" ;;
    esac
}

# --- Phase 3.5: Source Validation ---
if [ "$INSTALL_MODE" = "remote" ]; then
    chmod +x "$SRC"
fi

if ! is_official_cplay "$SRC"; then
    echo "❌ Error: The resolved source is not a valid official cplay binary."
    echo "   This usually happens if the remote assets are missing or corrupted (e.g. 404 page)."
    exit 1
fi

# --- Audit Logic ---
echo "--- Auditing System ---"
for path in "$BIN_OS_ROOT" "$BIN_OS_USR" "$BIN_SYS" "$BIN_USR" "$BIN_OPT" "$BIN_TMP"; do
    if [ -f "$path/$BIN_NAME" ]; then
        echo "[FOUND] $path/$BIN_NAME"
    fi
done

dep_missing=0
opt_missing=0

# Audit Required
for dep in $DEPS_REQUIRED; do
    cmd="${dep%%:*}"
    min_ver="${dep#*:}"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "⚠️  [REQUIRED MISSING] $cmd"
        if [ "$cmd" = "curl" ]; then
            echo "❌ Critical error: curl is required to proceed. Exiting."
            exit 1
        fi
        dep_missing=1
    else
        inst_ver=$(get_installed_version "$cmd")
        cmp=$(posix_version_compare "$inst_ver" "$min_ver")
        case "$cmp" in
            major|minor|patch|hotfix)
                echo "⚠️  [VERSION ERROR] $cmd $inst_ver < $min_ver"
                dep_missing=1 ;;
            *) echo "✅ [OK] $cmd $inst_ver (>= $min_ver)" ;;
        esac
    fi
done

# Audit Optional
for dep in $DEPS_OPTIONAL; do
    cmd="${dep%%:*}"
    min_ver="${dep#*:}"
    
    # Special case for magick (ImageMagick) which can be 'magick' or 'convert'
    check_cmd="$cmd"
    if [ "$cmd" = "magick" ]; then
        if ! command -v magick >/dev/null 2>&1 && ! command -v convert >/dev/null 2>&1; then
            check_cmd="false"
        fi
    fi

    if ! command -v "$check_cmd" >/dev/null 2>&1; then
        echo "ℹ️  [OPTIONAL MISSING] $cmd"
        # Curl is only fatal if we are in remote mode
        if [ "$cmd" = "curl" ] && [ "$INSTALL_MODE" = "remote" ]; then
            echo "❌ Critical error: curl is required for remote installation. Exiting."
            exit 1
        fi
        opt_missing=1
    else
        inst_ver=$(get_installed_version "$cmd")
        cmp=$(posix_version_compare "$inst_ver" "$min_ver")
        case "$cmp" in
            major|minor|patch|hotfix)
                echo "ℹ️  [OPTIONAL VERSION ERROR] $cmd $inst_ver < $min_ver"
                opt_missing=1 ;;
            *) echo "✅ [OK] $cmd $inst_ver" ;;
        esac
    fi
done

# Audit Audio Output (Exclusive OR)
echo "--- Auditing Audio Output ---"
has_audio=0
if command -v pw-cat >/dev/null 2>&1; then
    ver=$(get_installed_version "pw-cat")
    echo "✅ [OK] PipeWire (pw-cat) $ver"
    has_audio=1
fi

if command -v pacat >/dev/null 2>&1; then
    ver=$(get_installed_version "pacat")
    echo "✅ [OK] PulseAudio (pacat) $ver"
    has_audio=1
fi

if [ "$has_audio" -eq 0 ]; then
    echo "⚠️  [AUDIO MISSING] Neither PipeWire (pw-cat) nor PulseAudio (pacat) found."
    echo "   The raw engine will not produce sound without one of these."
    dep_missing=1
fi

echo "--- Audit Complete ---"

if [ "$dep_missing" -eq 1 ]; then
    echo
    echo "⚠️  Some required dependencies are missing or outdated."
    echo "   The installer will continue, but cplay may not work correctly."
fi

if [ "$opt_missing" -eq 1 ]; then
    echo
    echo "ℹ️  Optional features (Kitty graphics, metadata) are disabled."
    echo "   Install missing optional packages to unlock these features."
fi
echo

# --- Phase 4: Interactive Selection ---
echo
echo "Choose installation target:"
echo "1) System-wide: $BIN_SYS (Recommended)"
echo "2) User-specific: $BIN_USR"
printf "Enter choice [1-2, default=1]: "
read -r CHOICE < /dev/tty

# Handle default selection
[ -z "$CHOICE" ] && CHOICE="1"

case "$CHOICE" in
    1) BIN_TARGET="$BIN_SYS" ;;
    2) BIN_TARGET="$BIN_USR" ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac

echo "Targeting installation directory: $BIN_TARGET"

# --- Phase 5: Conflict Resolution ---
CONFLICTS=""
for path in "$BIN_OS_ROOT" "$BIN_OS_USR" "$BIN_SYS" "$BIN_USR" "$BIN_OPT"; do
    target_item="$path/$BIN_NAME"
    if [ -f "$target_item" ] && [ "$path" != "$BIN_TARGET" ]; then
        if [ -z "$CONFLICTS" ]; then
            CONFLICTS="$target_item"
        else
            CONFLICTS="$CONFLICTS
$target_item"
        fi
    fi
done

if [ -n "$CONFLICTS" ]; then
    echo
    echo "⚠️  CAUTION: Conflicting installations found:"
    
    IFS_use
    for item in $CONFLICTS; do
        if is_official_cplay "$item"; then
            echo "  - $item (Official cplay detected)"
        else
            echo "  - $item (UNKNOWN binary - potential name collision)"
        fi
    done
    IFS_rst

    echo "These may prevent your new version from running due to path precedence."
    printf "Would you like to remove these conflicting files? [y/N]: "
    read -r REMOVE_CHOICE < /dev/tty
    
    if [ "$REMOVE_CHOICE" = "y" ] || [ "$REMOVE_CHOICE" = "Y" ]; then
        printf "Type 'confirm' to delete these files: "
        read -r CONFIRM_STR < /dev/tty
        if [ "$CONFIRM_STR" = "confirm" ]; then
            IFS_use
            for item in $CONFLICTS; do
                IFS_rst
                SUDO_INTERNAL=""
                if [ ! -w "$(dirname "$item")" ] || [ ! -w "$item" ]; then
                    SUDO_INTERNAL="sudo"
                fi
                $SUDO_INTERNAL rm -f "$item"
                echo "Removed $item"
                IFS_use
            done
            IFS_rst
        else
            echo "Confirmation failed. Skipping removal."
        fi
    fi
fi

# --- Phase 6: Final Confirmation & Version Check ---
VERSION_TO_INSTALL=$(cat "$VERSION_SRC")
ACTION_MSG=""

if [ -f "$BIN_TARGET/$BIN_NAME" ]; then
    # Try to get version of the existing binary
    INSTALLED_VERSION=$("$BIN_TARGET/$BIN_NAME" --version 2>/dev/null || echo "unknown")
    
    if is_official_cplay "$BIN_TARGET/$BIN_NAME"; then
        CMP=$(posix_version_compare "$INSTALLED_VERSION" "$VERSION_TO_INSTALL")
        case "$CMP" in
            major|minor|patch|hotfix) ACTION_MSG="Upgrading from $INSTALLED_VERSION to $VERSION_TO_INSTALL" ;;
            downgrade) ACTION_MSG="Downgrading from $INSTALLED_VERSION to $VERSION_TO_INSTALL" ;;
            equal) ACTION_MSG="Reinstalling version $VERSION_TO_INSTALL" ;;
            *) ACTION_MSG="Updating $INSTALLED_VERSION -> $VERSION_TO_INSTALL" ;;
        esac
    else
        ACTION_MSG="Warning: $BIN_TARGET/$BIN_NAME is NOT an official binary. Overwriting..."
    fi
else
    ACTION_MSG="Installing version $VERSION_TO_INSTALL"
fi

echo
echo "--- Installation Summary ---"
echo "Target: $BIN_TARGET/$BIN_NAME"
echo "Action: $ACTION_MSG"
echo "Source: $INSTALL_MODE"
printf "Proceed with installation? [y/N]: "
read -r FINAL_CONFIRM < /dev/tty
[ "$FINAL_CONFIRM" != "y" ] && [ "$FINAL_CONFIRM" != "Y" ] && { echo "Installation cancelled."; exit 0; }


# --- Phase 7: Execution ---
echo "Installing..."

# 1. Setup Sudo if target directory isn't writable
SUDO_CMD=""
if [ ! -w "$BIN_TARGET" ] || [ ! -w "$(dirname "$BIN_TARGET")" ] 2>/dev/null; then
    SUDO_CMD="sudo"
fi

# 2. Ensure target directory exists
$SUDO_CMD mkdir -p "$BIN_TARGET"

# 3. Copy binary to destination
$SUDO_CMD cp "$SRC" "$BIN_TARGET/$BIN_NAME"

# 4. Set permissions
$SUDO_CMD chmod +x "$BIN_TARGET/$BIN_NAME"

echo
echo "✅ Installation successful!"
echo "Binary location: $BIN_TARGET/$BIN_NAME"
echo
echo "You can now run 'cplay' from your terminal."
echo "If the command is not found, ensure $BIN_TARGET is in your \$PATH."
echo
