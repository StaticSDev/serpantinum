#!/usr/bin/env bash
# ==============================================================================
# Serpantinum Rice Restore Script (Forked & Customized by StaticSDev)
# One-click full restoration for Hyprland + Quickshell + Liquid Shaders + Kitty
# ==============================================================================

set -e

# ANSI Color codes
BOLD="\033[1m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

log_info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()   { echo -e "${RED}[ERROR]${RESET} $*"; }
log_step()  { echo -e "\n${BOLD}${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }

print_banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    cat << "EOF"
  ____                               _   _                         
 / ___|  ___ _ __ _ __   __ _ _ __  | |_(_)_ __  _   _ _ __ ___    
 \___ \ / _ \ '__| '_ \ / _` | '_ \ | __| | '_ \| | | | '_ ` _ \   
  ___) |  __/ |  | |_) | (_| | | | || |_| | | | | |_| | | | | | |  
 |____/ \___|_|  | .__/ \__,_|_| |_| \__|_|_| |_|\__,_|_| |_| |_|  
                 |_|                                               
EOF
    echo -e "${RESET}"
    echo -e "${CYAN}${BOLD}   Serpantinum Rice Auto-Restore Script${RESET}"
    echo -e "${BLUE}   Forked & Maintained by StaticSDev: ${RESET}https://github.com/StaticSDev/serpantinum"
    echo -e "${YELLOW}   Includes: Liquid Glass Shaders, HyprWindowShade, Dynamic Kitty & Starship${RESET}"
    echo -e "------------------------------------------------------------------"
    echo ""
}

# Ensure not running as root
if [ "$EUID" -eq 0 ]; then
    log_err "Please run this script as your regular user (NOT as root or with sudo)."
    log_err "Sudo permissions will be requested when needed for package installation."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_banner

# ------------------------------------------------------------------------------
# Phase 1: Preflight & Package Manager
# ------------------------------------------------------------------------------
log_step "Phase 1: Checking system & package managers..."

if ! command -v pacman &>/dev/null; then
    log_err "This restore script requires an Arch Linux based distribution with pacman."
    exit 1
fi

# Enable multilib if needed
if grep -q "^#\[multilib\]" /etc/pacman.conf 2>/dev/null; then
    log_info "Enabling multilib repository in /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
fi

# Ensure base-devel, git, curl are installed
log_info "Checking essential bootstrap tools..."
MISSING_BOOTSTRAP=()
for tool in git curl jq unzip base-devel fontconfig; do
    if ! pacman -Qi "$tool" &>/dev/null && ! command -v "$tool" &>/dev/null; then
        MISSING_BOOTSTRAP+=("$tool")
    fi
done

if [ ${#MISSING_BOOTSTRAP[@]} -gt 0 ]; then
    log_info "Installing bootstrap tools: ${MISSING_BOOTSTRAP[*]}..."
    sudo pacman -Sy --noconfirm --needed "${MISSING_BOOTSTRAP[@]}"
fi

# AUR helper detection / bootstrap
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    log_info "No AUR helper detected. Bootstrapping yay-bin..."
    TEMP_YAY="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$TEMP_YAY"
    (cd "$TEMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TEMP_YAY"
    AUR_HELPER="yay"
fi
log_ok "Using AUR helper: ${AUR_HELPER}"

# ------------------------------------------------------------------------------
# Phase 2: Installing Dependencies
# ------------------------------------------------------------------------------
log_step "Phase 2: Installing core packages & rice dependencies..."

CORE_PKGS=(
    "hyprland"
    "kitty"
    "starship"
    "cava"
    "fastfetch"
    "pavucontrol"
    "alsa-utils"
    "wl-clipboard"
    "cliphist"
    "jq"
    "socat"
    "inotify-tools"
    "pamixer"
    "brightnessctl"
    "playerctl"
    "pipewire"
    "wireplumber"
    "pipewire-pulse"
    "pipewire-alsa"
    "libpulse"
    "python"
    "imagemagick"
    "grim"
    "slurp"
    "satty"
    "nautilus"
    "xdg-desktop-portal-hyprland"
    "xdg-desktop-portal-gtk"
    "qt6-wayland"
    "qt6-multimedia"
    "qt6-5compat"
    "qt6ct"
    "adw-gtk-theme"
)

AUR_PKGS=(
    "quickshell"
    "matugen"
)

log_info "Installing official repository packages..."
sudo pacman -Sy --noconfirm --needed "${CORE_PKGS[@]}"

log_info "Installing AUR packages (quickshell, matugen)..."
for pkg in "${AUR_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null && ! pacman -Qi "${pkg}-git" &>/dev/null && ! pacman -Qi "${pkg}-bin" &>/dev/null; then
        log_info "Installing $pkg via ${AUR_HELPER}..."
        $AUR_HELPER -S --noconfirm --needed "$pkg" || true
    fi
done

# Install Iosevka Nerd Font if missing
if ! fc-list : family | grep -iq "Iosevka"; then
    log_info "Installing Iosevka Nerd Font..."
    FONT_DIR="$HOME/.local/share/fonts/IosevkaNerdFont"
    mkdir -p "$FONT_DIR"
    FONT_ZIP="/tmp/Iosevka.zip"
    if curl -sSL --connect-timeout 15 --retry 3 "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip" -o "$FONT_ZIP"; then
        unzip -qo "$FONT_ZIP" -d "$FONT_DIR/" 2>/dev/null || true
        rm -f "$FONT_ZIP" "$FONT_DIR/"*Mono*.ttf 2>/dev/null || true
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
        log_ok "Iosevka Nerd Font installed."
    else
        log_warn "Failed to download fonts, skipping..."
    fi
fi

# ------------------------------------------------------------------------------
# Phase 3: Deploy Configurations
# ------------------------------------------------------------------------------
log_step "Phase 3: Deploying desktop configurations..."

# Hyprland config
mkdir -p "$HOME/.config/hypr"
if [ -d "$SCRIPT_DIR/compositors/hyprland" ]; then
    log_info "Deploying Hyprland config to ~/.config/hypr/..."
    cp -rf "$SCRIPT_DIR/compositors/hyprland/." "$HOME/.config/hypr/"
fi

# Kitty terminal config
mkdir -p "$HOME/.config/kitty"
if [ -d "$SCRIPT_DIR/config/kitty" ]; then
    log_info "Deploying Kitty config to ~/.config/kitty/..."
    cp -rf "$SCRIPT_DIR/config/kitty/." "$HOME/.config/kitty/"
fi

# Starship prompt config
if [ -f "$SCRIPT_DIR/config/starship/starship.toml" ]; then
    log_info "Deploying Starship prompt to ~/.config/starship.toml..."
    cp -f "$SCRIPT_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
fi

# Cava & Fastfetch configs
for cfg in cava fastfetch; do
    if [ -d "$SCRIPT_DIR/config/$cfg" ]; then
        mkdir -p "$HOME/.config/$cfg"
        cp -rf "$SCRIPT_DIR/config/$cfg/." "$HOME/.config/$cfg/"
    fi
done

# ------------------------------------------------------------------------------
# Phase 4: Deploy Liquid Shaders & HyprWindowShade Plugin
# ------------------------------------------------------------------------------
log_step "Phase 4: Deploying liquid shaders & HyprWindowShade plugin..."

# Shaders
mkdir -p "$HOME/.config/hypr/shaders"
if [ -d "$SCRIPT_DIR/src/assets/shaders" ]; then
    log_info "Deploying GLSL liquid shaders to ~/.config/hypr/shaders/..."
    cp -rf "$SCRIPT_DIR/src/assets/shaders/." "$HOME/.config/hypr/shaders/"
fi

# Hyprland Plugin
mkdir -p "$HOME/.local/share/hyprland/plugins"
if [ -d "$SCRIPT_DIR/src/assets/plugins" ]; then
    log_info "Deploying HyprWindowShade.so to ~/.local/share/hyprland/plugins/..."
    cp -rf "$SCRIPT_DIR/src/assets/plugins/." "$HOME/.local/share/hyprland/plugins/"
    chmod +x "$HOME/.local/share/hyprland/plugins/"* 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# Phase 5: Deploy Serpantinum Core & Daemons
# ------------------------------------------------------------------------------
log_step "Phase 5: Deploying Serpantinum shell & daemons..."

SERP_BASE="$HOME/.local/share/serpantinum"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$SERP_BASE/bin" "$SERP_BASE/src" "$BIN_DIR"

if [ -d "$SCRIPT_DIR/bin" ]; then
    cp -rf "$SCRIPT_DIR/bin/." "$SERP_BASE/bin/"
    chmod +x "$SERP_BASE/bin/"* 2>/dev/null || true
fi

if [ -d "$SCRIPT_DIR/src" ]; then
    cp -rf "$SCRIPT_DIR/src/." "$SERP_BASE/src/"
    find "$SERP_BASE/src/scripts" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
fi

# Binary symlinks
ln -sf "$SERP_BASE/bin/serpantinum" "$BIN_DIR/serpantinum"
ln -sf "$SERP_BASE/bin/serpantinumd" "$BIN_DIR/serpantinumd"
sudo ln -sf "$SERP_BASE/bin/serpantinum" /usr/local/bin/serpantinum 2>/dev/null || true
sudo ln -sf "$SERP_BASE/bin/serpantinumd" /usr/local/bin/serpantinumd 2>/dev/null || true

# Wallpapers directory & initial wallpapers
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"
if [ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
    log_info "Downloading bundled wallpaper pack..."
    CLONE_WALLPAPERS="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-wallpapers"
    rm -rf "$CLONE_WALLPAPERS"
    git clone --depth 1 "https://github.com/ilyamiro/shell-wallpapers.git" "$CLONE_WALLPAPERS" 2>/dev/null || true
    if [ -d "$CLONE_WALLPAPERS/images" ]; then
        cp -rf "$CLONE_WALLPAPERS/images/"* "$WALLPAPER_DIR/" 2>/dev/null || true
    fi
    rm -rf "$CLONE_WALLPAPERS"
fi

# Ensure user PATH has ~/.local/bin
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    log_info "Adding ~/.local/bin to PATH..."
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$rc"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
        fi
    done
fi

# ------------------------------------------------------------------------------
# Phase 6: Synchronize Shaders & Themes
# ------------------------------------------------------------------------------
log_step "Phase 6: Initializing dynamic color palettes..."

if [ -f "$SERP_BASE/src/scripts/theme/sync_shaders.py" ]; then
    python3 "$SERP_BASE/src/scripts/theme/sync_shaders.py" || true
    log_ok "Shaders, borders, Starship, and Kitty synchronized."
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}==================================================================${RESET}"
echo -e "${GREEN}${BOLD}   Serpantinum Rice Restoration Finished Successfully!${RESET}"
echo -e "${GREEN}${BOLD}==================================================================${RESET}"
echo ""
echo -e "  ${BOLD}What was restored:${RESET}"
echo -e "   ${CYAN}*${RESET} Hyprland 165Hz configuration with instant zero-lag dispatchers"
echo -e "   ${CYAN}*${RESET} GLSL liquid wave opening & closing shaders"
echo -e "   ${CYAN}*${RESET} HyprWindowShade plugin loaded automatically"
echo -e "   ${CYAN}*${RESET} Dynamic Kitty terminal theming with live reload"
echo -e "   ${CYAN}*${RESET} Dynamic Starship prompt synchronized with Serpantinum themes"
echo -e "   ${CYAN}*${RESET} Serpantinum bar, dock, and widgets daemon"
echo ""
echo -e "  ${BOLD}To start the session:${RESET}"
echo -e "   Type ${YELLOW}Hyprland${RESET} in your TTY or select Hyprland from your display manager."
echo ""
