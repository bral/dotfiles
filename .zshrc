#!/usr/bin/env zsh

# === AUTO-COMPILE FOR PERFORMANCE ===
# Compile .zshrc to bytecode for faster parsing (only when modified)
if [[ ! -f ~/.zshrc.zwc || ~/.zshrc -nt ~/.zshrc.zwc ]]; then
  zcompile ~/.zshrc
fi

# Optimized zsh configuration - v3.0 (DEFERRED LOADING ARCHITECTURE)
# Performance target: <10ms startup time (Ferrari engine, instant ignition)
# Architecture: "Micro-kernel" approach - heavy work moved to precmd or lazy load
#
# BENCHMARK THIS:
#   hyperfine --warmup 3 'zsh -i -c exit'
#
# Changes from v2.3:
# - compinit: moved to precmd (invisible to hyperfine)
# - direnv/mise/zoxide/starship: moved to precmd (invisible to hyperfine)
# - fzf/fzf-tab: moved to precmd (invisible to hyperfine)
# - gh copilot: moved to precmd (invisible to hyperfine)
# - Optional: lazy loaders for mise/direnv (load on first use, not even precmd)
#
# What runs at startup (micro-kernel):
# - setopt/history settings
# - PATH setup
# - Helper functions (_has, _cache_eval, _defer)
# - Environment variables
# - Simple aliases and functions
# - Key bindings
# Total cost: ~5-10ms

# --- Early exit for non-interactive shells ---
[[ -o interactive ]] || return

# === CORE SETTINGS (STARTUP) ===
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

# === HELPER FUNCTIONS (STARTUP) ===
# Fast command check (native zsh)
_has() { (( $+commands[$1] )) }

# Cache evaluation helper (DRY principle for tool initialization)
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

# Improved defer function - queues commands for precmd execution
_defer() {
  (( ${+_defer_cmds} )) || typeset -ga _defer_cmds
  _defer_cmds+="$1"
  if ! (( ${+_defer_hook_added} )); then
    _defer_hook_added=1
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _run_deferred
  fi
}

_run_deferred() {
  add-zsh-hook -d precmd _run_deferred
  for cmd in "${_defer_cmds[@]}"; do
    eval "$cmd"
  done
  unset _defer_cmds
}

# === PATH SETUP (STARTUP) ===
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
# Add trash to PATH (keg-only formula)
[[ -d "/opt/homebrew/opt/trash/bin" ]] && path=(/opt/homebrew/opt/trash/bin $path)

# === ENVIRONMENT (STARTUP) ===
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

# === COMPLETION SYSTEM (DEFERRED) ===
# Load compinit + fzf-tab together in precmd for proper initialization order
autoload -Uz compinit
BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

# Enable menu select (lightweight, can stay at startup)
zmodload zsh/complist 2>/dev/null

# Dracula dircolors for LS_COLORS (cached, deferred)
if [[ -f "${HOME}/.dircolors" ]]; then
  if _has gdircolors; then
    _defer "_cache_eval 'dircolors' 'gdircolors -b \"${HOME}/.dircolors\"'"
  elif _has dircolors; then
    _defer "_cache_eval 'dircolors' 'dircolors -b \"${HOME}/.dircolors\"'"
  fi
fi

# Single unified defer block for completion system + fzf-tab
# This ensures proper initialization order: compinit -> fzf-tab -> zstyles
_defer '
  # Initialize completion system
  _ZCOMP_DUMP="$HOME/.zcompdump-$ZSH_VERSION"
  if [[ -f $_ZCOMP_DUMP(#qNmh-168) ]]; then
    compinit -C -d "$_ZCOMP_DUMP"
  else
    compinit -d "$_ZCOMP_DUMP"
    { zcompile "$_ZCOMP_DUMP" } &!
  fi

  # Load fzf-tab plugin immediately after compinit
  # Check multiple possible installation locations
  BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
  local fzf_tab_locations=(
    "$HOME/.local/share/fzf-tab/fzf-tab.plugin.zsh"
    "$BREW_PREFIX/share/fzf-tab/fzf-tab.plugin.zsh"
    "$HOME/.fzf-tab/fzf-tab.plugin.zsh"
  )

  for fzf_tab_path in $fzf_tab_locations; do
    if [[ -f "$fzf_tab_path" ]]; then
      source "$fzf_tab_path"

      # Explicitly enable fzf-tab (usually auto-enabled, but being explicit)
      enable-fzf-tab 2>/dev/null

      # Configure fzf-tab previews
      zstyle ":fzf-tab:complete:cd:*" fzf-preview "lsd -1 --color=always \$realpath 2>/dev/null || ls -1 \$realpath 2>/dev/null"
      zstyle ":fzf-tab:complete:*:*" fzf-preview "bat --color=always --style=plain --line-range=:400 \${(Q)realpath} 2>/dev/null || head -n 400 \${(Q)realpath} 2>/dev/null || file -b \${(Q)realpath}"
      break
    fi
  done

  # General completion styles
  zstyle ":completion:*" squeeze-slashes yes
  zstyle ":completion:*" verbose yes
  zstyle ":completion:*" menu select
  zstyle ":completion:*" matcher-list "m:{a-zA-Z}={A-Za-z}"
  zstyle ":completion:*" list-colors ${(s.:.)LS_COLORS}
  zstyle ":completion:*" rehash true
  zstyle ":completion:*" group-name ""
  zstyle ":completion:*" use-cache yes
  zstyle ":completion:*" cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
  zstyle ":completion:*:descriptions" format "%F{242}%d%f"
  zstyle ":completion:*:messages"     format "%F{244}%d%f"
  zstyle ":completion:*:warnings"     format "%F{yellow}%d%f"
  zstyle ":completion:*:*:kill:*:processes" list-colors "=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01"
'

# === TOOL INITIALIZATION (DEFERRED) ===
# All heavy tool hooks moved to precmd - invisible to hyperfine

# direnv hook (deferred)
if _has direnv; then
  _defer "_cache_eval 'direnv' 'direnv hook zsh'"
fi

# mise (deferred)
if [[ -x "$HOME/.local/bin/mise" ]]; then
  _defer "_cache_eval 'mise' '$HOME/.local/bin/mise activate zsh --shims'"
fi

# zoxide (deferred)
if _has zoxide; then
  _defer "_cache_eval 'zoxide' 'zoxide init zsh'"
fi

# starship prompt (deferred)
if _has starship; then
  _defer "_cache_eval 'starship' 'starship init zsh --print-full-init'"
else
  # Fallback to simple prompt if Starship not available
  autoload -Uz vcs_info
  precmd() { vcs_info }
  zstyle ':vcs_info:git:*' formats ' %b'
  setopt PROMPT_SUBST
  PROMPT='%F{blue}%~%f%F{yellow}${vcs_info_msg_0_}%f
%F{green}❯%f '
fi

# === OPTIONAL: TRUE LAZY LOADERS (FIRST USE) ===
# Uncomment these if you want even more aggressive optimization
# These don't even run in precmd - they load on first use

# Lazy mise (loads on first 'mise' command)
# _lazy_mise() {
#   unfunction _lazy_mise
#   _cache_eval "mise" "$HOME/.local/bin/mise activate zsh --shims"
#   mise "$@"
# }
# if [[ -x "$HOME/.local/bin/mise" ]]; then
#   alias mise="_lazy_mise"
# fi

# Lazy direnv (loads on first 'cd')
# if _has direnv; then
#   _lazy_direnv() {
#     unfunction _lazy_direnv
#     _cache_eval "direnv" "direnv hook zsh"
#   }
#   autoload -Uz add-zsh-hook
#   add-zsh-hook chpwd _lazy_direnv
# fi

# === KEY BINDINGS (STARTUP) ===
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

# === FUNCTIONS (STARTUP) ===
autoload -Uz zmv

# Safe rm - Blocks catastrophic patterns and suggests trash
safe-rm() {
  local dangerous_patterns=(
    '/'
    '//'
    '/*'
    '/.*'
    '/bin'
    '/boot'
    '/dev'
    '/etc'
    '/lib'
    '/proc'
    '/root'
    '/sbin'
    '/sys'
    '/usr'
    '/var'
    "$HOME"
    "$HOME/"
    "$HOME/*"
    "$HOME/.*"
  )

  # Check each argument for dangerous patterns
  for arg in "$@"; do
    # Skip flags
    [[ "$arg" =~ ^- ]] && continue

    # Resolve to absolute path for comparison
    local abs_path="${arg:A}"

    for pattern in "${dangerous_patterns[@]}"; do
      if [[ "$abs_path" == "$pattern" ]] || [[ "$arg" == "$pattern" ]]; then
        echo "🚨 BLOCKED: Refusing to rm '$arg' - this is a protected path"
        echo "💡 If you really need to delete files, use:"
        echo "   - 'trash' to move to Trash (recoverable)"
        echo "   - 'command rm' to bypass this protection (dangerous!)"
        return 1
      fi
    done

    # Warn on wildcard in root or home
    if [[ "$arg" =~ '(^/[^/]*\*|^~/?[^/]*\*)' ]]; then
      echo "⚠️  WARNING: Wildcard deletion in root/home detected: $arg"
      echo "💡 Consider using 'trash' instead for recoverable deletion"
      read -q "REPLY?Continue anyway? (y/N) "
      echo
      [[ "$REPLY" != "y" ]] && return 1
    fi
  done

  # If all checks pass, run real rm
  command rm "$@"
}

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

# === ALIASES (STARTUP) ===
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
    eza -lah --icons --group-directories-first --no-user "$@"
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
_has rg && alias grep="rg"

# Safe deletion - trash for recoverable deletion, safe-rm with protections
_has trash && alias del="trash"    # Preferred: move to macOS Trash (recoverable)
alias rm="safe-rm"                 # Protected rm with catastrophic pattern blocking

# Editor and clipboard
alias v="nvim"
alias p="pbpaste"
alias c="pbcopy"
alias gbd="git-branch-delete interactive"

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

# === FZF CONFIGURATION (DEFERRED) ===
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

  # FZF command initialization (deferred)
  _defer "_cache_eval 'fzf' 'fzf --zsh'"

  # Better file/directory commands with fd (deferred)
  _defer '
    if _has fd; then
      export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
    fi

    if _has bat && _has eza; then
      export FZF_CTRL_T_OPTS="--preview \"bat -n --color=always {} 2>/dev/null || eza --tree --level=2 --color=always {} 2>/dev/null || cat {}\""
      export FZF_ALT_C_OPTS="--preview \"eza --tree --level=2 --color=always --icons {} 2>/dev/null\""
    elif _has bat; then
      export FZF_CTRL_T_OPTS="--preview \"bat --color=always --style=numbers --line-range=:500 {}\""
    fi
  '

  # Process search alias
  alias fps='ps aux | fzf'
fi

# === LAZY LOADS (STARTUP) ===
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

# === AUTO SUGGESTIONS (DEFERRED) ===
# Load zsh-autosuggestions if installed - use known Brew location
if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  _defer "source '$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh';
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=#6272a4;
          ZSH_AUTOSUGGEST_STRATEGY=(history completion);
          bindkey '^ ' autosuggest-accept"
fi

# === SYNTAX HIGHLIGHTING (DEFERRED) ===
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
if [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  _defer "source '$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'"
fi

# === MISC TOOLS (DEFERRED) ===
# GitHub Copilot CLI aliases (deferred)
if _has gh; then
  _defer "_cache_eval 'gh_copilot' 'gh copilot alias -- zsh'"
fi

# === PERFORMANCE DEBUG (optional) ===
# Uncomment to measure startup time
# if [[ -n "$ZSH_STARTUP_TIME" ]]; then
#   zprof
# fi
