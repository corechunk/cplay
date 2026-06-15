<div align="center">

# 🎵 corechunk / cplay
### *A Lightweight Terminal Music Player for Linux*

---

[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge&logo=gitbook&logoColor=white)](https://github.com/corechunk/cplay)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/platform-linux-lightgrey?style=for-the-badge&logo=linux&logoColor=white)](https://www.kernel.org/)
[![Kitty](https://img.shields.io/badge/kitty-graphics_api-F7B731?style=for-the-badge&logo=gnometerminal&logoColor=white)](https://sw.kovidgoyal.net/kitty/)
[![License](https://img.shields.io/badge/license-MIT-red?style=for-the-badge)](https://github.com/corechunk/cplay)

[🚀 Usage](#-usage) • [🎛️ Keybindings](#%EF%B8%8F-keybindings) • [🛠️ Features](#%EF%B8%8F-features) • [📂 Structure](#-project-structure) • [📦 Installation](#-local-installation--compilation)

---

</div>

## 📖 Overview

**cplay** is a fast, fully keyboard-driven music player for the Linux terminal. It is built in pure Bash with zero runtime dependencies beyond optional tools like `mpv` or `ffmpeg`. It features a rich interactive TUI, multi-engine playback, a file-tree browser, cover art via the Kitty graphics protocol, and a live queue manager — all compiled into a single portable script.

> [!IMPORTANT]
> cplay is compiled via `scripts/deploy` into a single portable `./cplay` binary. Always run `./scripts/deploy` after modifying any source file in `src/`.

---

## 🖼️ Screenshots

<div align="center">
  <p><i>(Screenshots coming soon!)</i></p>
</div>

---

## 🛠️ Features

- **🎵 Dual Playback Engine**: Switch between `raw` (native bash + aplay/paplay) and `mpv` at runtime with `-m mpv`.
- **📺 Interactive TUI Mode**: Full keyboard-driven terminal UI with multiple pages and live status updates.
- **📂 File Tree Browser**: Browse and expand source directories in a collapsible tree with queue toggling.
- **🎨 Cover Art**: Displays embedded album art directly in the terminal using the **Kitty graphics protocol** (`icat`).
- **🏷️ Track Metadata**: Extracts and displays title, artist, album, genre, date, and duration via `ffprobe`.
- **📋 Live Queue**: View and jump to any track in the active playlist queue.
- **🔁 Auto-Advance**: Automatically plays the next track in the queue when the current one ends.
- **🗂️ Source Management**: Add music folder sources at runtime; the tree browser auto-updates.
- **🔇 Mute / Volume / Seek**: Full playback controls from anywhere in the TUI.
- **🧩 Single Binary**: The entire project compiles to one standalone script via `scripts/deploy`.

---

## 🚀 Usage

### ⚡ Run Instantly (No Installation)

cplay is a single compiled script. You can test it directly from the web without touching your system:

```bash
# Launch default TUI mode straight from the web
bash <(curl -fsSL https://raw.githubusercontent.com/corechunk/cplay/main/cplay)

# Launch with a specific folder using mpv engine
bash <(curl -fsSL https://raw.githubusercontent.com/corechunk/cplay/main/cplay) -m mpv -f ~/Music
```

> [!TIP]
> No cloning, no compiling. Just pipe and play. Optional tools like `ffmpeg` and `kitty` unlock cover art — but the player works without them too.

### 📦 Installation (Recommended)

Install cplay to your system with our professional POSIX-compliant installer. It handles dependency checks, path conflicts, and official identity verification.

**Modern Method (Safest - Recommended for Interactivity)**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/corechunk/cplay/main/installer.sh)
```

**Classic Method (Most Portable)**
```bash
curl -fsSL https://raw.githubusercontent.com/corechunk/cplay/main/installer.sh | sh
```

> [!NOTE]
> The installer automatically detects if it is running from a local clone or via a remote download. If auto-detection fails, you can force the method using the `--local` or `--remote` flags:
> 
> ```bash
> # Force remote download mode
> curl -fsSL https://raw.githubusercontent.com/corechunk/cplay/main/installer.sh | sh -s -- --remote
> 
> # Force local installation mode
> ./installer.sh --local
> ```

### 🛠️ Manual Compilation & Installation

If you prefer to build from source or hack on the code:

```bash
# 1. Clone the repository
git clone https://github.com/corechunk/cplay.git
cd cplay

# 2. Compile into a single binary (Requires curl for bash-lib via internet)
# Optional - cplay is pre-compiled in the repo root
./scripts/deploy

# 3. Run the installer locally
./installer.sh
```


---

## 🎛️ Keybindings

### 🌐 Global — Work on Every Page

| Key | Action |
| :--- | :--- |
| `F1` | Main Player View |
| `F2` | File Tree / Source Browser |
| `F3` | Playlist Queue |
| `F4` | Diagnostics & System Info |
| `F5` | Track Metadata & Cover Art |
| `Ctrl + Right` | Next Track |
| `Ctrl + Left` | Previous Track |
| `Alt + Up` | Volume Up |
| `Alt + Down` | Volume Down |
| `Alt + Right` | Seek +10s |
| `Alt + Left` | Seek -10s |
| `n / N` | Next Track |
| `b / B` | Previous Track |
| `m / M` | Toggle Mute |
| `Esc / Ctrl+C` | Return to Main Menu |
| `Ctrl + Shift + C` | Quit cplay completely |

### 🏠 Main Menu (`F1`)

| Key | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `↑ / ↓` | Volume Up / Down |
| `← / →` | Seek -10s / +10s |
| `1` | Add a track by filepath or URL (link not implemented yet) |
| `2` | Add a music source directory (playlist link not implemented yet) |
| `i` | Diagnostics page (same as F4) |
| `q` | Queue page (same as F3) |
| `l` | Source browser (same as F2) |

### 📂 File Browser (`F2`)

| Key | Action |
| :--- | :--- |
| `↑ / ↓` | Navigate items |
| `→` | Expand directory |
| `←` | Collapse directory |
| `Space / Enter` | Toggle directory/file in queue |
| `s` | Toggle sort order (asc/desc) |

### 📋 Queue (`F3`)

| Key | Action |
| :--- | :--- |
| `↑ / ↓` | Navigate tracks |
| `Space / Enter` | Jump to and play selected track |

### 🏷️ Metadata (`F5`)

| Key | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `↑ / ↓` | Volume Up / Down |
| `← / →` | Seek -10s / +10s |

---

## 📋 Summary Reference

### 🛠️ Dependencies

| Category | Tool | Description | Min Version | Required? |
| :--- | :--- | :--- | :---: | :---: |
| **Required** | `bash` | Core shell runtime | 4.0 | Yes |
| **Required** | `ffmpeg` | Decodes audio for raw engine | 0.5 | Yes |
| **Required** | `ffprobe` | Extracts track metadata | 0.5 | Yes |
| **Required** | `pipewire` | Audio output via `pw-cat` | - | Yes* |
| **Required** | `pulseaudio` | Audio output via `pacat` | - | Yes* |
| **Optional** | `mpv` | Alternative playback engine | 0.17.0 | Optional |
| **Optional** | `kitty` | Terminal graphics support | 0.10.0 | Optional |
| **Optional** | `imagemagick`| Required for Kitty's `icat` | - | Optional |
| **Optional** | `curl` | Asset fetching & updates | 7.80.0 | Optional |

*\* Either **PipeWire** or **PulseAudio** is required for the default raw engine.*

### 🎛️ Flags

| Flag | Alias | Description |
| :--- | :--- | :--- |
| `--tui` | `-t` | Launch in interactive TUI mode (**Default**) |
| `--menu` | | Launch in classic interactive menu mode |
| `--cli` | | Launch in non-interactive CLI mode (WIP) |
| `--folder DIR` | `-f DIR` | Open cplay with a specific music folder |
| `--mode mpv` | `-m mpv` | Use mpv as the playback engine |
| `--mode raw` | `-m raw` | Use the raw bash engine |
| `--identity` | | Show official application identity |
| `--provider` | | Show developer provider information |
| `--check-imports` | `-c` | Run diagnostics check and exit |
| `--version` | | Show version information |
| `--verbose` | `-v` | Enable verbose output |
| `--help` | `-h` | Show this help message |

### ⚙️ Installer Flags (`installer.sh`)

| Flag | Description |
| :--- | :--- |
| `--local` | Force local installation mode |
| `--remote` | Force remote download installation mode |

---

## 📂 Project Structure

```
cplay/
├── cplay                       # Compiled single-binary output
├── VERSION                     # Version manifest
├── scripts/
│   ├── deploy                  # Compilation script (bash-lib)
│   └── test_kitty_meta.sh      # Standalone Kitty icat + metadata test tool
└── src/
    ├── main.sh                 # Entry point
    ├── backend/
    │   ├── driver_mpv.sh       # MPV engine driver
    │   └── driver_raw.sh       # Raw bash engine driver
    ├── config/
    │   ├── env.sh              # Global state variables & Kitty detection
    │   ├── keys.sh             # Keybinding config
    │   └── playlist.sh         # Playlist configuration
    ├── core/
    │   ├── flags.sh            # CLI flag parser
    │   ├── meta.sh             # Metadata & cover art loader (ffprobe/ffmpeg)
    │   ├── player.sh           # Core playback control (play/pause/next/prev)
    │   ├── playlist_manager.sh # Queue management logic
    │   └── traps.sh            # Cleanup & signal traps
    ├── libs/
    │   └── imports.sh          # bash-lib import loader
    └── ui/
        ├── menu.sh             # Non-TUI interactive menu
        ├── tui.sh              # TUI main loop & keybinding dispatcher
        ├── tui_browser.sh      # File tree browser state & logic
        └── tui_views.sh        # All page render functions
```

---

## 🤝 Contributing

Contributions are always welcome! Feel free to open an issue or submit a pull request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

<div align="center">

### 🎵 Keep Playing
Built with ❤️ by [netchunk](https://github.com/netchunk)

[Back to Top](#-corechunk--cplay)

</div>