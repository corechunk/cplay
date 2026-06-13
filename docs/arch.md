# cplay Architecture & Design Specification

This document details the architectural design for `cplay`, a lightweight terminal music player written in Bash. It covers the core control loops, terminal input parsing, the dual-engine playback system, and process management.

---

## 1. High-Level Architecture

`cplay` is divided into two decoupling layers:
1. **Interactive Control Loop (Frontend/Foreground):** Handles key bindings, terminal raw mode, UI state rendering, and user control.
2. **Playback Engine Driver (Backend/Background):** Manages audio processes, audio servers (PulseAudio/PipeWire), or high-level player backends (`mpv`).

```mermaid
flowchart TD
    Init[cplay Entrypoint] --> SetupTerminal[Enable Trap & Raw Mode]
    SetupTerminal --> LoadDriver{Is 'mpv' installed?}
    
    LoadDriver -->|Yes| MPVDriver[Load MPV IPC Driver]
    LoadDriver -->|No| RawDriver[Load Raw PCM Driver]
    
    MPVDriver --> InputLoop[Key Input Loop]
    RawDriver --> InputLoop
    
    subgraph Frontend (Foreground Process)
        InputLoop -->|Capture Key| ActionRouter[Action Router]
    end
    
    subgraph Backend (Background Daemon/Processes)
        ActionRouter -->|Execute Command| API[Standard Driver API]
        API -->|IPC / Process Signals| Engine[Active Playback Process]
    end
```

---

## 2. Interactive Input Loop & Key Bindings

To capture keypresses instantly without waiting for the user to press `[Enter]`, the terminal must be put into **non-canonical raw mode** with disabled input echo.

### Terminal Modes Setup & Cleanup
Before entering the loop, the script modifies the standard terminal (`stty`) settings and registers a cleanup trap to guarantee the terminal is restored to normal upon script termination or interruption.

```bash
# Save original terminal settings
OLD_STTY=$(stty -g)

cleanup() {
    # Restore terminal settings
    stty "$OLD_STTY"
    # Show cursor
    tput cnorm
    # Kill active player process groups
    kill -TERM -"$PLAYER_PGID" 2>/dev/null
    exit 0
}

# Trap exit signals
trap cleanup EXIT SIGINT SIGTERM
```

### Keypress Parser & Modifier Keys
Because modifier keys (like `Ctrl` or `Alt` + arrow keys) send multi-byte escape sequences, the input loop reads bytes sequentially when an escape character (`\e`) is detected:

| Key Combination | Raw Escape Sequence | Decoded Bytes | Action |
| :--- | :--- | :--- | :--- |
| **Spacebar** | ` ` | ` ` (space) | Play / Pause Toggle |
| **Up Arrow** | `\e[A` | `\e`, `[`, `A` | Volume Up |
| **Down Arrow** | `\e[B` | `\e`, `[`, `B` | Volume Down |
| **Left Arrow** | `\e[D` | `\e`, `[`, `D` | Seek Back (-10s) |
| **Right Arrow** | `\e[C` | `\e`, `[`, `C` | Seek Forward (+10s) |
| **Ctrl + Left** | `\e[1;5D` | `\e`, `[`, `1`, `;`, `5`, `D` | Previous Track |
| **Ctrl + Right** | `\e[1;5C` | `\e`, `[`, `1`, `;`, `5`, `C` | Next Track |
| **Alt + Up** | `\e[1;3A` | `\e`, `[`, `1`, `;`, `3`, `A` | Seek Forward (+1m) |
| **Alt + Down** | `\e[1;3B` | `\e`, `[`, `1`, `;`, `3`, `B` | Seek Back (-1m) |
| **q** | `q` | `q` | Exit Player |

---

## 3. Dual-Engine Playback System

To support premium features (instant seeking, efficient streaming) while remaining highly portable, `cplay` implements an abstract Player Driver API backed by two engines:

### Engine A: Premium Engine (`mpv` IPC) - Default
Used when `mpv` is installed on the host system.
*   **Mechanism:** `cplay` starts `mpv` as a headless background process with an IPC socket enabled:
    ```bash
    mpv --idle --no-video --input-ipc-server=/tmp/cplay-mpv.sock &
    ```
*   **Controls:** IPC control commands are sent directly to the UNIX socket using `socat` or Bash redirection `/dev/tcp`:
    *   *Pause:* `{"command": ["set_property", "pause", true]}`
    *   *Seek:* `{"command": ["seek", 10]}`
*   **Efficiency:** High-efficiency seeking via internal media demuxing and buffering. No process recreation required.

### Engine B: Portable Engine (Raw PCM Pipeline) - Fallback
Used when `mpv` is missing, but system decoders/mixers (`ffmpeg` and PipeWire/PulseAudio) are available.
*   **Mechanism:** Decodes file formats to raw PCM stdout and pipes directly to a playback utility:
    ```bash
    ffmpeg -ss $OFFSET -i "$FILE" -f s16le -acodec pcm_s16le - | pw-cat --playback --format=s16le -
    ```
*   **State Control:**
    *   *Pause:* Send process stop signal (`kill -STOP $PLAYER_PID`).
    *   *Resume:* Send process continue signal (`kill -CONT $PLAYER_PID`).
    *   *Seek:* Record the current time progress, calculate the new target time, terminate the active pipeline (`kill -TERM $PLAYER_PID`), and spawn a new one with the updated `-ss $NEW_OFFSET` parameters.
    *   *Volume:* Control system-level sink volumes via `wpctl` (PipeWire) or `pactl` (PulseAudio).

---

## 4. Lifecycle & Asynchronous Events Loop

Because the input loop is blocking, the player runs a non-blocking poll to detect when the current track naturally ends:

```bash
while true; do
    # Non-blocking key read (0.2s timeout)
    if read -t 0.2 -rn1 key; then
        handle_keypress "$key"
    fi

    # Check if the player process is still active
    if ! kill -0 "$PLAYER_PID" 2>/dev/null; then
        if [ "$PAUSE_STATE" = "false" ]; then
            # Player exited naturally; current song has finished
            play_next_track
        fi
    fi
done
```
