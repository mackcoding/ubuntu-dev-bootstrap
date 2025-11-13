#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check if whiptail is available
if ! command -v whiptail &> /dev/null; then
    log_warn "Installing whiptail for interactive menu..."
    sudo apt-get update && sudo apt-get install -y whiptail
fi

# Define installation options
declare -A INSTALL_OPTIONS=(
    ["system_update"]="System Update & Basic Packages"
    ["git_config"]="Git Configuration (name & email)"
    ["homebrew"]="Homebrew Package Manager"
    ["ohmyzsh"]="Oh My Zsh"
    ["starship"]="Starship Prompt"
    ["brew_tools"]="Brew Tools (k9s, kubectl, kind, etc)"
    ["bun"]="Bun Runtime"
    ["docker"]="Docker & Docker Compose"
    ["kompose"]="Kompose (Kubernetes)"
    ["jsonnet_bundler"]="Jsonnet Bundler (jb)"
    ["zed"]="Zed Code Editor"
    ["ghostty"]="Ghostty Terminal"
    ["zoom"]="Zoom"
)

# Check if git is already configured
GIT_CONFIG_DEFAULT="ON"
if git config --global user.name &> /dev/null && git config --global user.email &> /dev/null; then
    GIT_CONFIG_DEFAULT="OFF"
fi

# Show selection menu
CHOICES=$(whiptail --title "Ubuntu Setup" --checklist \
    "Select components to install (Space to toggle, Enter to confirm):" 20 78 13 \
    "system_update" "${INSTALL_OPTIONS[system_update]}" ON \
    "git_config" "${INSTALL_OPTIONS[git_config]}" "$GIT_CONFIG_DEFAULT" \
    "homebrew" "${INSTALL_OPTIONS[homebrew]}" ON \
    "ohmyzsh" "${INSTALL_OPTIONS[ohmyzsh]}" ON \
    "starship" "${INSTALL_OPTIONS[starship]}" ON \
    "brew_tools" "${INSTALL_OPTIONS[brew_tools]}" ON \
    "bun" "${INSTALL_OPTIONS[bun]}" ON \
    "docker" "${INSTALL_OPTIONS[docker]}" ON \
    "kompose" "${INSTALL_OPTIONS[kompose]}" ON \
    "jsonnet_bundler" "${INSTALL_OPTIONS[jsonnet_bundler]}" ON \
    "zed" "${INSTALL_OPTIONS[zed]}" ON \
    "ghostty" "${INSTALL_OPTIONS[ghostty]}" ON \
    "zoom" "${INSTALL_OPTIONS[zoom]}" ON \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    log_error "Installation cancelled"
    exit 1
fi

# Convert choices to array
SELECTED=($(echo $CHOICES | tr -d '"'))

log_info "Starting installation..."

# System Update & Basic Packages
if [[ " ${SELECTED[@]} " =~ " system_update " ]]; then
    log_info "Updating system and installing basic packages..."
    sudo apt update && sudo apt dist-upgrade -y
    sudo apt install -y git curl zsh build-essential procps file clamav clamav-daemon gnome-browser-connector htop tree jq btop neovim plocate golang-go
fi

# Git Configuration
if [[ " ${SELECTED[@]} " =~ " git_config " ]]; then
    log_info "Configuring Git..."

    GIT_NAME=$(whiptail --inputbox "Enter your Git name:" 8 60 "$(git config --global user.name 2>/dev/null || echo '')" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        log_warn "Git name configuration skipped"
    else
        GIT_EMAIL=$(whiptail --inputbox "Enter your Git email:" 8 60 "$(git config --global user.email 2>/dev/null || echo '')" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            log_warn "Git email configuration skipped"
        else
            git config --global user.name "$GIT_NAME"
            git config --global user.email "$GIT_EMAIL"
            log_info "Git configured: $GIT_NAME <$GIT_EMAIL>"
        fi
    fi
fi

# Homebrew
if [[ " ${SELECTED[@]} " =~ " homebrew " ]]; then
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
        log_warn "Homebrew already installed, updating..."
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        brew update && brew upgrade
    fi
fi

# Oh My Zsh
if [[ " ${SELECTED[@]} " =~ " ohmyzsh " ]]; then
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log_warn "Oh My Zsh already installed, upgrading..."
        (cd "$HOME/.oh-my-zsh" && git pull)
    fi
fi

# Starship
if [[ " ${SELECTED[@]} " =~ " starship " ]]; then
    if command -v brew &> /dev/null; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

        if brew list starship &> /dev/null; then
            log_warn "Starship already installed, upgrading..."
            brew upgrade starship 2>/dev/null || log_info "Starship already up-to-date"
        else
            log_info "Installing Starship prompt via Homebrew..."
            brew install starship
        fi
    else
        log_error "Homebrew not installed, skipping Starship (install Homebrew first)"
    fi

    # Only create config if it doesn't exist
    if [ ! -f ~/.config/starship.toml ]; then
        mkdir -p ~/.config
        starship preset gruvbox-rainbow -o ~/.config/starship.toml
        sed -i 's/time_format = "%R"/time_format = "%r"/' ~/.config/starship.toml
        log_info "Created starship config with gruvbox theme"
    fi

    # Add to shell configs if not present
    grep -q 'eval "$(starship init' ~/.zshrc 2>/dev/null || echo 'eval "$(starship init zsh)"' >> ~/.zshrc
    grep -q 'eval "$(starship init' ~/.bashrc 2>/dev/null || echo 'eval "$(starship init bash)"' >> ~/.bashrc
fi

# Brew Tools
if [[ " ${SELECTED[@]} " =~ " brew_tools " ]]; then
    log_info "Installing brew tools..."
    if command -v brew &> /dev/null; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

        # Define packages to install
        BREW_PACKAGES=(k9s kubectl kind tanka codex gemini-cli helix)
        BREW_CASKS=(claude-code)

        # Install or upgrade regular packages
        for package in "${BREW_PACKAGES[@]}"; do
            if brew list "$package" &> /dev/null; then
                log_warn "$package already installed, upgrading..."
                brew upgrade "$package" 2>/dev/null || log_info "$package already up-to-date"
            else
                log_info "Installing $package..."
                brew install "$package"
            fi
        done

        # Install or upgrade casks
        for cask in "${BREW_CASKS[@]}"; do
            if brew list --cask "$cask" &> /dev/null; then
                log_warn "$cask already installed, upgrading..."
                brew upgrade --cask "$cask" 2>/dev/null || log_info "$cask already up-to-date"
            else
                log_info "Installing $cask..."
                brew install --cask "$cask"
            fi
        done
    else
        log_error "Homebrew not installed, skipping brew tools"
    fi
fi

# Bun
if [[ " ${SELECTED[@]} " =~ " bun " ]]; then
    if ! command -v bun &> /dev/null; then
        log_info "Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
    else
        log_warn "Bun already installed, upgrading..."
        bun upgrade
    fi
fi

# Docker
if [[ " ${SELECTED[@]} " =~ " docker " ]]; then
    if command -v docker &> /dev/null; then
        log_warn "Docker already installed, upgrading..."
        sudo apt-get update
        sudo apt-get install -y --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        log_info "Installing Docker..."

        # Remove old versions
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            sudo apt-get remove -y $pkg 2>/dev/null || true
        done

        sudo apt-get update
        sudo apt-get install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER

        log_warn "You'll need to log out and back in for Docker group membership to take effect"
    fi
fi

# Kompose
if [[ " ${SELECTED[@]} " =~ " kompose " ]]; then
    if ! command -v kompose &> /dev/null; then
        log_info "Installing Kompose..."
        curl -L https://github.com/kubernetes/kompose/releases/download/v1.34.0/kompose-linux-amd64 -o /tmp/kompose
        chmod +x /tmp/kompose
        sudo mv /tmp/kompose /usr/local/bin/kompose
    else
        log_warn "Kompose already installed, upgrading..."
        curl -L https://github.com/kubernetes/kompose/releases/download/v1.34.0/kompose-linux-amd64 -o /tmp/kompose
        chmod +x /tmp/kompose
        sudo mv /tmp/kompose /usr/local/bin/kompose
    fi
fi

# Jsonnet Bundler
if [[ " ${SELECTED[@]} " =~ " jsonnet_bundler " ]]; then
    if ! command -v jb &> /dev/null; then
        log_info "Installing Jsonnet Bundler (jb)..."
        sudo curl -Lo /usr/local/bin/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/latest/download/jb-linux-amd64
        sudo chmod a+x /usr/local/bin/jb
    else
        log_warn "Jsonnet Bundler already installed, upgrading..."
        sudo curl -Lo /usr/local/bin/jb https://github.com/jsonnet-bundler/jsonnet-bundler/releases/latest/download/jb-linux-amd64
        sudo chmod a+x /usr/local/bin/jb
    fi
fi

# Jsonnet (via Go)
if [[ " ${SELECTED[@]} " =~ " brew_tools " ]]; then
    if command -v jsonnet &> /dev/null; then
        log_warn "Jsonnet already installed, upgrading..."
        go install github.com/google/go-jsonnet/cmd/jsonnet@latest
        go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
    else
        log_info "Installing Jsonnet via Go..."
        go install github.com/google/go-jsonnet/cmd/jsonnet@latest
        go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
    fi
fi

# Zed
if [[ " ${SELECTED[@]} " =~ " zed " ]]; then
    if ! command -v zed &> /dev/null; then
        log_info "Installing Zed editor..."
        curl -f https://zed.dev/install.sh | sh
    else
        log_warn "Zed already installed, upgrading..."
        curl -f https://zed.dev/install.sh | sh
    fi
fi

# Ghostty
if [[ " ${SELECTED[@]} " =~ " ghostty " ]]; then
    if command -v ghostty &> /dev/null; then
        log_warn "Ghostty already installed, upgrading..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
    else
        log_info "Installing Ghostty..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
    fi

    # Only create theme if it doesn't exist
    if [ ! -f ~/.config/ghostty/themes/ubuntu ]; then
        mkdir -p ~/.config/ghostty/themes
        cat > ~/.config/ghostty/themes/ubuntu << 'EOF'
# Ubuntu GNOME Terminal Default Theme
background = 300a24
foreground = ffffff

palette = 0=#2e3436
palette = 1=#cc0000
palette = 2=#4e9a06
palette = 3=#c4a000
palette = 4=#3465a4
palette = 5=#75507b
palette = 6=#06989a
palette = 7=#d3d7cf
palette = 8=#555753
palette = 9=#ef2929
palette = 10=#8ae234
palette = 11=#fce94f
palette = 12=#729fcf
palette = 13=#ad7fa8
palette = 14=#34e2e2
palette = 15=#eeeeec

cursor-color = ffffff
selection-background = ffffff
selection-foreground = 300a24
EOF
        log_info "Created Ubuntu theme for Ghostty"
    fi

    # Only add theme line if not present
    mkdir -p ~/.config/ghostty
    grep -q "^theme = ubuntu" ~/.config/ghostty/config 2>/dev/null || echo "theme = ubuntu" >> ~/.config/ghostty/config
fi

# Zoom
if [[ " ${SELECTED[@]} " =~ " zoom " ]]; then
    if command -v zoom &> /dev/null; then
        log_warn "Zoom already installed, upgrading..."
        cd /tmp
        wget -q https://zoom.us/client/latest/zoom_amd64.deb
        sudo apt install -y ./zoom_amd64.deb
        rm -f /tmp/zoom_amd64.deb
    else
        log_info "Installing Zoom..."
        cd /tmp
        wget -q https://zoom.us/client/latest/zoom_amd64.deb
        sudo apt install -y ./zoom_amd64.deb
        rm -f /tmp/zoom_amd64.deb

        # Only configure if config doesn't exist or settings are missing
        mkdir -p ~/.config
        touch ~/.config/zoomus.conf

        # Configure Zoom for Wayland (only if not already set)
        grep -q "^enableWaylandShare=" ~/.config/zoomus.conf || \
            echo "enableWaylandShare=true" >> ~/.config/zoomus.conf

        grep -q "^XDG_CURRENT_DESKTOP=" ~/.config/zoomus.conf || \
            echo "XDG_CURRENT_DESKTOP=gnome" >> ~/.config/zoomus.conf

        grep -q "^enableMiniWindow=" ~/.config/zoomus.conf || \
            echo "enableMiniWindow=true" >> ~/.config/zoomus.conf

        log_info "Configured Zoom for Wayland"
    fi
fi

log_info "Installation complete!"
log_warn "Please restart your shell or run: exec \$SHELL"
