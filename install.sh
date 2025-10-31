#!/usr/bin/env bash

# Dotfiles Installation Script
# Safely symlinks dotfiles and sets up the development environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration (bash 3.2 compatible - macOS default)
SYMLINK_SOURCES=(
    "$DOTFILES_DIR/.zshrc"
    "$DOTFILES_DIR/.zshenv"
    "$DOTFILES_DIR/.p10k.zsh"
    "$DOTFILES_DIR/hammerspoon_init.lua"
)

SYMLINK_TARGETS=(
    "$HOME/.zshrc"
    "$HOME/.zshenv"
    "$HOME/.p10k.zsh"
    "$HOME/.hammerspoon/init.lua"
)

# Backup existing file
backup_file() {
    local file="$1"
    if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$file" "$backup"
        success "Backed up existing file: $file → $backup"
        return 0
    fi
    return 1
}

# Create symlink safely
create_symlink() {
    local source="$1"
    local target="$2"
    local target_dir="$(dirname "$target")"
    
    # Create target directory if it doesn't exist
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        success "Created directory: $target_dir"
    fi
    
    # Handle existing files
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            local current_link="$(readlink "$target")"
            if [[ "$current_link" == "$source" ]]; then
                info "Already linked: $target → $source"
                return 0
            fi
            warning "Removing existing symlink: $target → $current_link"
            rm "$target"
        else
            echo
            bold "Existing file found: $target"
            echo "1) Backup and replace"
            echo "2) Skip this file"
            echo "3) Abort installation"
            read -p "Choose [1/2/3]: " choice
            
            case $choice in
                1)
                    backup_file "$target"
                    ;;
                2)
                    warning "Skipped: $target"
                    return 0
                    ;;
                3)
                    error "Installation aborted by user"
                    exit 1
                    ;;
                *)
                    error "Invalid choice. Aborting."
                    exit 1
                    ;;
            esac
        fi
    fi
    
    # Create the symlink
    ln -sf "$source" "$target"
    success "Linked: $target → $source"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    local missing=()
    local can_install=()
    
    # Check for essential tools
    if ! command -v brew >/dev/null; then
        missing+=("homebrew")
        can_install+=("homebrew")
    fi
    
    if ! command -v git >/dev/null; then
        missing+=("git")
        # git will be installed via Command Line Tools or Homebrew
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warning "Missing dependencies: ${missing[*]}"
        if [[ ${#can_install[@]} -gt 0 ]]; then
            info "These can be auto-installed: ${can_install[*]}"
        fi
        return 1
    fi
    
    success "All essential dependencies found"
    return 0
}

# Install Homebrew
install_homebrew() {
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        # Apple Silicon Mac
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        # Intel Mac
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    if command -v brew >/dev/null; then
        success "Homebrew installed successfully"
    else
        error "Homebrew installation failed"
        return 1
    fi
}

# Install optional dependencies
install_dependencies() {
    if ! command -v brew >/dev/null; then
        bold "Homebrew is required but not installed"
        echo "Install Homebrew now? [Y/n]"
        read -p "> " install_brew
        if [[ ! "$install_brew" =~ ^[Nn] ]]; then
            install_homebrew || return 1
        else
            error "Homebrew is required for dependency installation"
            return 1
        fi
    fi
    
    info "Installing recommended packages..."

    local packages=(
        "zsh"
        "git"
        "gh"                        # GitHub CLI (for Copilot in .zshrc)
        "direnv"                    # Environment switcher (used in .zshrc)
        "lsd"
        "bat"
        "fd"
        "fzf"
        "tree"
        "zoxide"
        "jq"                        # JSON processor (commonly used)
        "mise"                      # Version manager (replaces curl | sh)
    )
    # Note: zsh plugins (powerlevel10k, autosuggestions, syntax-highlighting)
    # are installed via z4h, not brew
    
    for package in "${packages[@]}"; do
        if brew list "$package" >/dev/null 2>&1; then
            info "$package already installed"
        else
            info "Installing $package..."
            brew install "$package"
        fi
    done

    # Install mise tools from config if mise is available
    if command -v mise >/dev/null; then
        info "Installing development tools via mise..."
        mise install || warning "Some mise tools may have failed to install"
        mise upgrade || warning "mise upgrade failed (non-critical)"
    fi

    success "Dependencies installed"
}

# Setup shell framework
setup_shell() {
    local z4h_dir="$HOME/.cache/zsh4humans/v5"
    local required_files=(
        "$z4h_dir/powerlevel10k/powerlevel10k.zsh-theme"
        "$z4h_dir/zsh-autosuggestions/zsh-autosuggestions.zsh"
        "$z4h_dir/zsh-history-substring-search/zsh-history-substring-search.zsh"
        "$z4h_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    )

    # Check if installation is complete
    local install_needed=false
    if [[ ! -d "$z4h_dir" ]]; then
        install_needed=true
    else
        for file in "${required_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                warning "Missing z4h file: $file"
                install_needed=true
                break
            fi
        done
    fi

    if [[ "$install_needed" == true ]]; then
        info "Installing zsh4humans framework..."

        # Remove any incomplete installation
        rm -rf "$HOME/.cache/zsh4humans"
        mkdir -p "$z4h_dir"

        # Download z4h core
        info "Downloading z4h core..."
        curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/z4h.zsh -o "$z4h_dir/z4h.zsh"

        # Download required plugins directly
        info "Downloading powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$z4h_dir/powerlevel10k" >/dev/null 2>&1

        info "Downloading zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$z4h_dir/zsh-autosuggestions" >/dev/null 2>&1

        info "Downloading zsh-history-substring-search..."
        git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search.git "$z4h_dir/zsh-history-substring-search" >/dev/null 2>&1

        info "Downloading zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$z4h_dir/zsh-syntax-highlighting" >/dev/null 2>&1

        # Create required directories
        mkdir -p "$z4h_dir"/{bin,cache,fn,terminfo,tmp,stickycache}

        # Verify installation
        local verification_failed=false
        for file in "${required_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                error "Failed to install: $file"
                verification_failed=true
            fi
        done

        if [[ "$verification_failed" == true ]]; then
            error "Z4H installation verification failed"
            return 1
        fi

        success "zsh4humans installed successfully"
    else
        info "zsh4humans already installed and complete"
    fi
}

# Make scripts executable
setup_bin() {
    info "Setting up bin directory..."
    
    if [[ -d "$DOTFILES_DIR/bin" ]]; then
        chmod +x "$DOTFILES_DIR/bin"/*
        success "Made bin scripts executable"
    fi
}

# Verify installation
verify_installation() {
    info "Verifying installation..."

    local errors=0

    for i in "${!SYMLINK_SOURCES[@]}"; do
        local source="${SYMLINK_SOURCES[$i]}"
        local target="${SYMLINK_TARGETS[$i]}"

        if [[ -L "$target" ]]; then
            local link_target="$(readlink "$target")"
            if [[ "$link_target" == "$source" ]]; then
                success "✓ $target → $source"
            else
                error "✗ $target points to wrong location: $link_target"
                ((errors++))
            fi
        else
            error "✗ $target is not a symlink"
            ((errors++))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        success "All symlinks verified successfully"
        return 0
    else
        error "$errors verification errors found"
        return 1
    fi
}

# Uninstall function
uninstall_dotfiles() {
    bold "🗑️  Dotfiles Uninstallation"
    echo "This will remove all symlinks created by this dotfiles installation."
    echo
    
    warning "This action cannot be undone!"
    echo "Continue with uninstallation? [y/N]"
    read -p "> " confirm
    
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        info "Uninstallation cancelled"
        return 0
    fi
    
    info "Removing symlinks..."

    local removed=0
    for i in "${!SYMLINK_SOURCES[@]}"; do
        local source="${SYMLINK_SOURCES[$i]}"
        local target="${SYMLINK_TARGETS[$i]}"

        if [[ -L "$target" ]]; then
            local link_target="$(readlink "$target")"
            if [[ "$link_target" == "$source" ]]; then
                rm "$target"
                success "Removed: $target"
                ((removed++))
            else
                warning "Skipped: $target (points to different location)"
            fi
        elif [[ -e "$target" ]]; then
            warning "Skipped: $target (not a symlink)"
        else
            info "Not found: $target"
        fi
    done
    
    if [[ $removed -gt 0 ]]; then
        success "Uninstallation completed: $removed symlinks removed"
        echo
        info "Note: Dependencies and frameworks (zsh4humans, brew packages) were not removed"
        info "Backup files (.backup.*) were preserved"
    else
        warning "No symlinks were removed"
    fi
}

# Main installation function
main() {
    bold "🏠 Dotfiles Installation"
    echo "Repository: $DOTFILES_DIR"
    echo
    
    # Verify we're in the right directory
    if [[ ! -f "$DOTFILES_DIR/.zshrc" ]]; then
        error "This doesn't appear to be a dotfiles repository"
        error "Missing .zshrc file in $DOTFILES_DIR"
        exit 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        echo
        bold "Install missing dependencies? [Y/n]"
        read -p "> " install_deps
        if [[ ! "$install_deps" =~ ^[Nn] ]]; then
            install_dependencies || {
                error "Dependency installation failed"
                exit 1
            }
        else
            warning "Some features may not work without dependencies"
        fi
    fi
    
    echo
    bold "📁 Creating symlinks..."

    # Create all symlinks
    for i in "${!SYMLINK_SOURCES[@]}"; do
        local source="${SYMLINK_SOURCES[$i]}"
        local target="${SYMLINK_TARGETS[$i]}"
        create_symlink "$source" "$target"
    done
    
    # Setup bin directory
    setup_bin
    
    echo
    bold "🔧 Setting up shell framework..."
    
    # Ask about shell setup
    if [[ ! -d "$HOME/.cache/zsh4humans" ]]; then
        echo "Install zsh4humans framework? [Y/n]"
        read -p "> " setup_z4h
        if [[ ! "$setup_z4h" =~ ^[Nn] ]]; then
            setup_shell
        fi
    else
        info "zsh4humans already installed"
    fi
    
    echo
    bold "✅ Verification"
    verify_installation
    
    echo
    success "Installation completed successfully!"
    echo
    bold "Next steps:"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Install Hammerspoon from: https://www.hammerspoon.org"
    echo "3. Run 'up' to update your system"
    echo "4. Use 'hyper + 8' in Hammerspoon to check app bundle IDs"
    echo
    info "For more information, see README.md"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Dotfiles Installation Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --verify       Only verify existing installation"
        echo "  --uninstall    Remove all dotfiles symlinks"
        echo "  --deps         Only install dependencies"
        echo
        exit 0
        ;;
    --verify)
        verify_installation
        exit $?
        ;;
    --deps)
        install_dependencies
        exit $?
        ;;
    --uninstall)
        uninstall_dotfiles
        exit $?
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac