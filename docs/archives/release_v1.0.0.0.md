2026-06-16 02:05:00

## Release Status: v1.0.0.0 (Final Hardened)

### 🔗 Remotes
- **GitHub**: [https://github.com/corechunk/cplay/releases/tag/v1.0.0.0](https://github.com/corechunk/cplay/releases/tag/v1.0.0.0)
- **GitLab**: [https://gitlab.com/corechunk/cplay/-/releases/v1.0.0.0](https://gitlab.com/corechunk/cplay/-/releases/v1.0.0.0)

### 📦 Assets (Synchronized)
- `cplay`: Standalone monolithic binary (v1.0.0.0)
- `VERSION`: Version manifest file (renamed from .version for asset safety)
- `installer.sh`: POSIX-compliant installer with remote-fetch capabilities

### ✅ Critical Fixes Applied
- [x] **Function Reordering**: Helpers moved to top of `installer.sh` to prevent 'not found' errors during piped execution.
- [x] **Asset Safety**: Renamed `.version` to `VERSION` to prevent GitHub from auto-renaming it to `default.version`.
- [x] **Security Hardening**: Source validation via `is_official_cplay` ensures 404 pages aren't installed as binaries.
- [x] **Dual Remote Sync**: Verified simultaneous release creation on GitHub and GitLab.

### 🛠️ Environment
- Build Date: 2026-06-16
- Target Platform: Linux (Generic)
- Min Bash: 4.0
