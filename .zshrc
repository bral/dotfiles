#!/usr/bin/env zsh

# === AUTO-COMPILE FOR PERFORMANCE ===
# Compile .zshrc to bytecode for faster parsing (only when modified)
if [[ ! -f ~/.zshrc.zwc || ~/.zshrc -nt ~/.zshrc.zwc ]]; then
  zcompile ~/.zshrc
fi

# Optimized zsh configuration - v2.3 (Performance Optimized)
# Performance target: <30ms startup time (instant)
# - Reduced repetition via _cache_eval helper
# - Removed dead P10k code
# - Standardized on Brew paths
# - Removed duplicate env vars (see .zshenv)
# - Auto-compile for faster parsing
# - Cached heavy binaries (starship, gh copilot, dircolors)
# - Background compilation of completion dump
# - EXTENDED_GLOB enabled for cache qualifiers

# --- Early exit for non-interactive shells ---
[[ -o interactive ]] || return

# === CORE SETTINGS ===
setopt EXTENDED_GLOB  # CRITICAL: Required for (#qNmh-XX) cache qualifiers to work
setopt EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE HIST_VERIFY SHARE_HISTORY
setopt APPEND_HISTORY INC_APPEND_HISTORY HIST_FCNTL_LOCK
setopt HIST_REDUCE_BLANKS HIST_SAVE_NO_DUPS
setopt GLOB_DOTS NO_AUTO_MENU
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

# --- Fast command check (native zsh) ---
_has() { (( $+commands[$1] )) }

# --- Cache evaluation helper (DRY principle for tool initialization) ---
_cache_eval() {
  local cmdname="$1"
  local cmd="$2"
  local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/${cmdname}_init.zsh"

  # Refresh cache if missing or older than 7 days (#qNmh-168)
  if [[ ! -f "$cache_file"(#qNmh-168) ]]; then
    mkdir -p "$(dirname "$cache_file")"
    eval "$cmd" >| "$cache_file" 2>/dev/null
  fi
  source "$cache_file"
}

# === PATH SETUP ===
typeset -U path PATH
path=(
  $HOME/.local/bin
  $HOME/bin
  /opt/homebrew/bin
  /usr/local/bin
  $path
)
# Add Go path only if it exists
[[ -d "$HOME/go/bin" ]] && path=($HOME/go/bin $path)

# === ENVIRONMENT ===
# Note: EDITOR and VISUAL are set in .zshenv
export GPG_TTY=$TTY
export MISE_NODE_COREPACK=true

# Colored man pages using bat (if available)
if _has bat; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# PAI System paths
export PAI_HOME="$HOME"
export PAI_DIR="$HOME/PAI"
export PROJECTS_DIR="$HOME/Projects"
export CONSULTING_DIR="$HOME/Consulting"

# Source secrets if present (not compiled for security)
[[ -f "$HOME/.secrets.zsh" ]] && source "$HOME/.secrets.zsh"

# direnv hook (early so cd/env takes effect before other hooks)
_has direnv && _cache_eval "direnv" "direnv hook zsh"

# === COMPLETION SYSTEM ===
# Enable menu select
zmodload zsh/complist 2>/dev/null

# Defer function
autoload -Uz add-zsh-hook
_defer() {
  typeset -g _defer_body="$*"
  add-zsh-hook -Uz precmd _defer_run
  _defer_run() { add-zsh-hook -d precmd _defer_run; eval "$_defer_body"; unset _defer_body; unset -f _defer_run; }
}

# Fast compinit with versioned dump to avoid churn after upgrades
autoload -Uz compinit
_ZCOMP_DUMP="$HOME/.zcompdump-$ZSH_VERSION"
if [[ -f $_ZCOMP_DUMP(#qNmh-168) ]]; then
  compinit -C -d "$_ZCOMP_DUMP"
else
  compinit -d "$_ZCOMP_DUMP"
  # Compile the dump file in background for next startup
  { zcompile "$_ZCOMP_DUMP" } &!
fi

# fzf-tab AFTER compinit - use known Brew location
BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
[[ -f "$BREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh" ]] && source "$BREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh"

# Dracula dircolors for LS_COLORS (cached for performance)
if [[ -f "${HOME}/.dircolors" ]]; then
  if _has gdircolors; then
    _cache_eval "dircolors" "gdircolors -b '${HOME}/.dircolors'"
  elif _has dircolors; then
    _cache_eval "dircolors" "dircolors -b '${HOME}/.dircolors'"
  fi
fi

# Better completion defaults
zstyle ':completion:*' squeeze-slashes yes
zstyle ':completion:*' verbose yes
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' rehash true
zstyle ':completion:*' group-name ''
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*:descriptions' format '%F{242}%d%f'
zstyle ':completion:*:messages'     format '%F{244}%d%f'
zstyle ':completion:*:warnings'     format '%F{yellow}%d%f'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

# fzf-tab configuration
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always $realpath 2>/dev/null || ls -1 $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --color=always --style=plain --line-range=:400 ${(Q)realpath} 2>/dev/null || head -n 400 ${(Q)realpath} 2>/dev/null || file -b ${(Q)realpath}'

# === TOOL INITIALIZATION ===
# mise (fast version manager)
[[ -x "$HOME/.local/bin/mise" ]] && _cache_eval "mise" "$HOME/.local/bin/mise activate zsh --shims"

# zoxide (smart cd)
_has zoxide && _cache_eval "zoxide" "zoxide init zsh"

# === KEY BINDINGS ===
bindkey -e  # Emacs mode
bindkey '^[[1;5D' backward-word  # Ctrl+Left
bindkey '^[[1;5C' forward-word   # Ctrl+Right
bindkey '^[[H' beginning-of-line # Home
bindkey '^[[F' end-of-line       # End
bindkey '^[[3~' delete-char      # Delete
bindkey '^?' backward-delete-char # Backspace
bindkey '^[[Z' reverse-menu-complete # Shift+Tab

# Word movement consistency (remove - and / from word chars)
WORDCHARS='*?_[]~=&;!#$%^(){}<>'

# Magic Enter - context-aware empty command
# Press Enter on empty line: shows git status (if in repo) or ls
magic-enter() {
  if [[ -z $BUFFER ]]; then
    echo ""
    if git rev-parse --is-inside-work-tree &>/dev/null; then
      # In git repo: show status and brief file list
      git status
      echo ""
      if _has eza; then
        eza --icons --group-directories-first -1 | head -n 5
      else
        ls -1 | head -n 5
      fi
    else
      # Not in repo: just list files
      if _has eza; then
        eza --icons --group-directories-first --no-user
      else
        ls -lah
      fi
    fi
    zle redisplay
  else
    zle accept-line
  fi
}
zle -N magic-enter
bindkey "^M" magic-enter

# === FUNCTIONS ===
autoload -Uz zmv

# Auto-list directory contents after cd, prefer fastest available
chpwd() {
  if (( $+commands[eza] )); then eza -lah --icons --group-directories-first --no-user 2>/dev/null
  elif (( $+commands[lsd] )); then lsd -lah 2>/dev/null
  else ls -lah
  fi
}

# Create and enter directory
md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }

# Copy working directory to clipboard
cpwd() { pwd | tr -d '\n' | pbcopy }

# Copy file contents to clipboard
cpf() {
  if [[ -f "$1" ]]; then
    cat "$1" | pbcopy
    echo "✓ Copied contents of $1"
  else
    echo "✗ '$1' is not a valid file"
    return 1
  fi
}

# Universal extract function
extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar e "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "✗ '$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "✗ '$1' is not a valid file"
    return 1
  fi
}
alias x="extract"

# === ALIASES ===
# Quick directory jumps
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Core utilities (Modern Rust-based tools)
# eza - Modern ls replacement
# Dracula theme colors for eza
export EZA_COLORS="reset:di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34"
if _has eza; then
  alias ls="eza --icons --group-directories-first --no-user"
  l() {
    eza -lah --icons --group-directories-first --no-user --total-size "$@"
  }
  alias ll="eza -lh --icons --group-directories-first --no-user"
  alias la="eza -a --icons --group-directories-first --no-user"
  alias tree="eza --tree --icons"
else
  # Fallback to lsd if eza not available
  alias l="lsd -lah --total-size"
  alias ll="lsd -lh"
fi

# yazi - Modern file manager
_has yazi && alias y="yazi"

# Modern system tools
_has procs && alias ps="procs"
_has duf && alias df="duf"
_has dust && alias du="dust"

# Editor and clipboard
alias v="nvim"
alias p="pbpaste"
alias c="pbcopy"

# Claude AI
alias claude="~/.claude/local/claude"
alias cc="cd ~/PAI && claude"

# Zoxide aliases (optional cd replacement)
# Set ZOXIDE_REPLACE_CD=1 in .zshenv to replace cd with z
if _has zoxide; then
  [[ "${ZOXIDE_REPLACE_CD}" == "1" ]] && alias cd="z"
  (( $+functions[zi] )) && alias cdi="zi"
  alias zz="z -"  # Go to previous directory
fi

# Git essentials
alias g="git"
alias ga="git add"
alias gb="git branch"
alias gc="git commit"
alias gcm="git commit -m"
alias gco="git checkout"
alias gd="git diff"
alias gf="git fetch --all"
alias gl="git log --oneline --graph"
alias gm="git merge"
alias gp="git push"
alias gpl="git pull"
alias gs="git status"
alias gst="git stash"
alias gstp="git stash pop"

# === FZF CONFIGURATION ===
if _has fzf; then
  # Enhanced FZF options with Dracula colors and better UX
  export FZF_DEFAULT_OPTS="
    --height=50%
    --layout=reverse
    --border=rounded
    --info=inline
    --preview-window=right:60%:wrap
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-u:preview-page-up'
    --bind='ctrl-d:preview-page-down'
    --bind='ctrl-y:execute-silent(echo -n {+} | pbcopy)'
    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
  "

  # Initialize fzf shell integration
  _cache_eval "fzf" "fzf --zsh"

  # Better file/directory commands with fd
  if _has fd; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi

  # Enhanced previews with bat and eza
  if _has bat && _has eza; then
    export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always {} 2>/dev/null || eza --tree --level=2 --color=always {} 2>/dev/null || cat {}'"
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {} 2>/dev/null'"
  elif _has bat; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  fi

  # Process search alias
  alias fps='ps aux | fzf'
fi

# === LAZY LOADS ===
# System update function - calls optimized update-system script
up() {
  local cmd="${1:-full}"
  # Map 'all' to 'full' for convenience
  [[ "$cmd" == "all" ]] && cmd="full"

  if [[ -x "$HOME/Projects/dotfiles/bin/update-system" ]]; then
    "$HOME/Projects/dotfiles/bin/update-system" "$cmd"
  else
    echo "Error: update-system script not found or not executable"
    return 1
  fi
}

# Load project functions only when needed
proj() {
  source "$HOME/.config/zsh/projects.zsh" 2>/dev/null || {
    echo "Error: projects.zsh not found"
    return 1
  }
  proj "$@"
}

# Fabric lazy load with error handling
fabric() {
  unfunction fabric 2>/dev/null
  if [[ -f "$HOME/.config/fabric/fabric-bootstrap.inc" ]]; then
    source "$HOME/.config/fabric/fabric-bootstrap.inc"
  fi
  if _has fabric; then
    command fabric "$@"
  else
    echo "Error: fabric not found in PATH" >&2
    return 1
  fi
}

# Load Fabric helper functions (smart-commit, ai-commit, doc-code, get-todos)
if [[ -f "$HOME/Projects/dotfiles/bin/fabric-helpers" ]]; then
  source "$HOME/Projects/dotfiles/bin/fabric-helpers" >/dev/null 2>&1
fi

# === AUTO SUGGESTIONS ===
# Load zsh-autosuggestions if installed - use known Brew location
if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  _defer "source '$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh';
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=#6272a4;
          ZSH_AUTOSUGGEST_STRATEGY=(history completion);
          bindkey '^ ' autosuggest-accept"
fi

# === SYNTAX HIGHLIGHTING ===
# Dracula theme colors for zsh-syntax-highlighting
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[comment]='fg=#6272a4'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#50fa7b,bold'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#50fa7b,bold'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#50fa7b,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#50fa7b,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=#50fa7b,bold'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#50fa7b,bold,italic'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#ffb86c,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#ffb86c'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#ffb86c'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#bd93f9'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#8be9fd,bold'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#8be9fd,bold'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#8be9fd,bold'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#ff79c6'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[default]='fg=#f8f8f2'
ZSH_HIGHLIGHT_STYLES[cursor]='standout'


# Load syntax highlighting if installed - use known Brew location (must be near the end)
[[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
  _defer "source '$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'"

# === PROMPT ===
# Starship prompt - Fast, cross-shell compatible (replaces P10k)
# Cached for performance (saves ~20-40ms)
if _has starship; then
  _cache_eval "starship" "starship init zsh --print-full-init"
else
  # Fallback to simple prompt if Starship not available
  autoload -Uz vcs_info
  precmd() { vcs_info }
  zstyle ':vcs_info:git:*' formats ' %b'
  setopt PROMPT_SUBST
  PROMPT='%F{blue}%~%f%F{yellow}${vcs_info_msg_0_}%f
%F{green}❯%f '
fi

# === MISC TOOLS ===
# GitHub Copilot CLI aliases (cached for performance)
# Blindly attempt to cache - if extension is missing, cache file is empty (safe to source)
_has gh && _cache_eval "gh_copilot" "gh copilot alias -- zsh"

# === PERFORMANCE DEBUG (optional) ===
# Uncomment to measure startup time
# if [[ -n "$ZSH_STARTUP_TIME" ]]; then
#   zprof
# fi
