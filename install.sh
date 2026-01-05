#!/usr/bin/env bash
# Dotfiles Installation Script (Modernized)

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Symlink Configuration
# Note: .p10k.zsh removed (using Starship)
declare -A SYMLINKS=(
    ["$DOTFILES_DIR/.zshrc"]="$HOME/.zshrc"
    ["$DOTFILES_DIR/.zshenv"]="$HOME/.zshenv"
    ["$DOTFILES_DIR/hammerspoon_init.lua"]="$HOME/.hammerspoon/init.lua"
    ["$DOTFILES_DIR/config/zsh/fzf-git-functions.zsh"]="$HOME/.config/zsh/fzf-git-functions.zsh"
)

create_symlinks() {
    info "Creating symlinks..."
    mkdir -p "$HOME/.hammerspoon"
    mkdir -p "$HOME/.config/zsh"

    for source in "${!SYMLINKS[@]}"; do
        local target="${SYMLINKS[$source]}"
        if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            mv "$target" "${target}.backup"
            warning "Backed up existing $target to ${target}.backup"
        fi
        ln -sf "$source" "$target"
        success "Linked $target"
    done
}

# 2. Install Dependencies
install_deps() {
    info "Checking dependencies..."

    if ! command -v brew >/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Use Brewfile as single source of truth
    if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
        info "Installing bundle from Brewfile..."
        brew bundle --file="$DOTFILES_DIR/Brewfile" || warning "Some brew items failed"
    else
        # Fallback list if Brewfile missing
        brew install zsh git gh direnv starship lsd bat fd fzf tree zoxide jq
    fi
}

# 3. Post-Install Setup
setup_post() {
    # Make scripts executable
    chmod +x "$DOTFILES_DIR/bin"/* 2>/dev/null || true

    # Install mise tools if present
    if command -v mise >/dev/null; then
        info "Installing runtime tools (mise)..."
        mise install || true
    fi
}

main() {
    echo "🚀 Starting Dotfiles Install..."
    install_deps
    create_symlinks
    setup_post
    echo ""
    success "Installation Complete! Restart your shell."
}

main
