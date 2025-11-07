# Ubuntu Dev Bootstrap

Interactive setup script for bootstrapping a fresh Ubuntu installation with common development tools and configurations.

## What It Does

Provides a TUI menu to selectively install and configure:

- **System Updates** - Latest packages and security updates
- **Git Configuration** - Set your name and email
- **Homebrew** - Package manager for Linux
- **Oh My Zsh** - Enhanced shell with plugins
- **Starship** - Modern shell prompt with Gruvbox theme
- **Dev Tools** - kubectl, k9s, kind, codex, gemini-cli, claude-code
- **Bun** - Fast JavaScript runtime
- **Docker** - Container platform with compose
- **Kompose** - Kubernetes conversion tool
- **Zed** - Modern code editor
- **Ghostty** - Modern terminal emulator with Ubuntu theme
- **Zoom** - Video conferencing with Wayland support

## Usage

**Quick Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/mackcoding/ubuntu-dev-bootstrap/refs/heads/main/ubuntu-setup.sh | bash
```

**Or clone and run:**
```bash
git clone https://github.com/mackcoding/ubuntu-dev-bootstrap.git
cd ubuntu-dev-bootstrap
./ubuntu-setup.sh
```

Use Space to toggle selections, Enter to confirm. All options are selected by default.

> **Security Note:** The one-liner executes the script directly from GitHub. Review the script contents before running if you have security concerns.

## Requirements

- Fresh Ubuntu installation
- sudo access
- Internet connection

## Notes

- The script is idempotent - safe to run multiple times
- Git should be installed before configuring (system_update includes it)
- Docker group membership requires logout/login to take effect
- Homebrew tools require Homebrew to be selected first

---

*Generated with [Claude Code](https://claude.com/claude-code)*
