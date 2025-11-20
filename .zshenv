#!/usr/bin/env zsh
# .zshenv - Environment variables

# Standard XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# Language & Editors
export LANG="${LANG:-en_US.UTF-8}"

# Default programs
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"
export PAGER="${PAGER:-less}"

# Homebrew (Apple Silicon)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi