#!/usr/bin/env zsh
# .zshenv - Environment variables loaded for all zsh sessions

# Z4H cache directory (required for zsh4humans)
: "${Z4H:=${XDG_CACHE_HOME:-$HOME/.cache}/zsh4humans/v5}"

# Standard XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# Ensure locale is set properly
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Default programs
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"
export PAGER="${PAGER:-less}"

# Development paths
export GOPATH="${GOPATH:-$HOME/go}"

# Homebrew environment (for Apple Silicon Macs)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ -f "/usr/local/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/usr/local"
fi