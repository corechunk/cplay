# Release v1.0.0.1 (Hotfix)

### 🛠️ Changes
- **Fixed Kitty Detection**: `check_kitty_support` now relies strictly on `$TERM=kitty` to correctly identify the terminal session. This fixes the issue where child terminals (like Alacritty) launched from within Kitty inherited incorrect environment flags, causing glitchy behavior.
- **Improved Installer**: Interactive `read` commands now explicitly redirect to `/dev/tty`, ensuring the installer remains fully interactive even when piped directly from the web (`curl | sh`).
- **Version Bump**: Bumped from `1.0.0.0` to `1.0.0.1`.
