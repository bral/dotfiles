#!/usr/bin/env zsh
# Optimized zsh configuration - v2.1
# Performance target: <40ms startup time

# --- Early exit for non-interactive shells ---
[[ -o interactive ]] || return

# === INSTANT PROMPT (Must be first) ===
# Powerlevel10k instant prompt - DISABLED (migrated to Starship)
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# === CORE SETTINGS ===
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
export GPG_TTY=$TTY
export EDITOR=nvim
export VISUAL=nvim
export MISE_NODE_COREPACK=true

# PAI System paths
export PAI_HOME="$HOME"
export PAI_DIR="$HOME/PAI"
export PROJECTS_DIR="$HOME/Projects"
export CONSULTING_DIR="$HOME/Consulting"

# Source secrets if present (not compiled for security)
[[ -f "$HOME/.secrets.zsh" ]] && source "$HOME/.secrets.zsh"

# direnv hook (early so cd/env takes effect before other hooks) - cached
if _has direnv; then
  _DIRENV_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/direnv_hook.zsh"
  if [[ ! -f $_DIRENV_CACHE(#qNmh-168) ]]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    direnv hook zsh >| "$_DIRENV_CACHE"
  fi
  source "$_DIRENV_CACHE"
fi

# === COMPLETION SYSTEM ===
# Enable menu select
zmodload zsh/complist 2>/dev/null

# Defer function
autoload -Uz add-zsh-hook
_defer() {
  local body="$*"
  add-zsh-hook -Uz precmd _defer_run
  _defer_run() { add-zsh-hook -d precmd _defer_run; eval "$body"; unset -f _defer_run; }
}

# Fast compinit with versioned dump to avoid churn after upgrades
autoload -Uz compinit
_ZCOMP_DUMP="$HOME/.zcompdump-$ZSH_VERSION"
if [[ -f $_ZCOMP_DUMP(#qNmh-168) ]]; then
  compinit -C -d "$_ZCOMP_DUMP"
else
  compinit -d "$_ZCOMP_DUMP"
fi

# fzf-tab AFTER compinit (cached path lookup)
_FZF_TAB_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/fzf_tab_path"
if [[ -f "$_FZF_TAB_CACHE" ]]; then
  source "$(cat "$_FZF_TAB_CACHE")" 2>/dev/null || rm -f "$_FZF_TAB_CACHE"
else
  for f in ~/.local/share/fzf-tab/fzf-tab.plugin.zsh \
    /opt/homebrew/share/fzf-tab/fzf-tab.plugin.zsh \
    /usr/share/fzf-tab/fzf-tab.plugin.zsh; do
    if [[ -f $f ]]; then
      echo "$f" > "$_FZF_TAB_CACHE"
      source "$f"
      break
    fi
  done
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
# mise (fast version manager) - cached
if [[ -x "$HOME/.local/bin/mise" ]]; then
  _MISE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/mise_activate.zsh"
  if [[ ! -f $_MISE_CACHE(#qNmh-168) ]]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    $HOME/.local/bin/mise activate zsh --shims >| "$_MISE_CACHE" 2>/dev/null || true
  fi
  source "$_MISE_CACHE"
fi

# zoxide (smart cd) - cache the init output for performance
_ZOX_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zoxide_init.zsh"
if _has zoxide; then
  if [[ ! -f $_ZOX_CACHE(#qNmh-168) ]]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    zoxide init zsh >| "$_ZOX_CACHE"
  fi
  source "$_ZOX_CACHE"
fi

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

# === FUNCTIONS ===
autoload -Uz zmv

# Auto-list directory contents after cd, prefer fastest available
chpwd() {
  if (( $+commands[eza] )); then eza -lah --icons 2>/dev/null
  elif (( $+commands[lsd] )); then lsd -lah 2>/dev/null
  else ls -lah
  fi
}

# Create and enter directory
md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }

# Copy working directory to clipboard
cpwd() { pwd | tr -d '\n' | pbcopy }

# === ALIASES ===
# Quick directory jumps
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Core utilities (Modern Rust-based tools)
# eza - Modern ls replacement
if _has eza; then
  alias ls="eza --icons"
  alias l="eza -lah --icons"
  alias ll="eza -lh --icons"
  alias la="eza -a --icons"
  alias tree="eza --tree --icons"
else
  # Fallback to lsd if eza not available
  alias l="lsd -lah"
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
  # Enhanced FZF options with Catppuccin colors and better UX
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
    --color=fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8
    --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8
    --color=info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc
    --color=marker:#f5e0dc,spinner:#f5e0dc,header:#f38ba8
  "

  _FZF_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/fzf_zsh_init"
  _FZF_VER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/fzf_version"

  # Cache fzf version separately to avoid running fzf --version every startup
  if [[ -f "$_FZF_VER_CACHE"(#qNmh-168) ]]; then
    _FZF_VER="$(cat "$_FZF_VER_CACHE")"
  else
    _FZF_VER="$(fzf --version 2>/dev/null | awk '{print $1}')"
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    echo "$_FZF_VER" > "$_FZF_VER_CACHE"
  fi

  if [[ ! -f $_FZF_CACHE(#qNmh-168) ]] || ! grep -q "FZF_VERSION=$_FZF_VER" "$_FZF_CACHE" 2>/dev/null; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    {
      echo "FZF_VERSION=$_FZF_VER"
      fzf --zsh
    } >| "$_FZF_CACHE"
  fi
  source "$_FZF_CACHE"

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
# Load update functions only when needed
up() {
  source "$HOME/.config/zsh/updates.zsh" 2>/dev/null || {
    echo "Error: updates.zsh not found"
    return 1
  }
  up "$@"
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
# Load zsh-autosuggestions if installed (cached path lookup)
_AUTOSUGGEST_PATH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/autosuggest_path"
if [[ -f "$_AUTOSUGGEST_PATH_CACHE" ]]; then
  _defer "source \"$(cat "$_AUTOSUGGEST_PATH_CACHE")\";
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=244;
          ZSH_AUTOSUGGEST_STRATEGY=(history completion);
          bindkey '^ ' autosuggest-accept"
else
  for autosuggest_file in /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
                          /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
                          ~/.local/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    if [[ -f "$autosuggest_file" ]]; then
      echo "$autosuggest_file" > "$_AUTOSUGGEST_PATH_CACHE"
      _defer "source \"$autosuggest_file\";
              ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=244;
              ZSH_AUTOSUGGEST_STRATEGY=(history completion);
              bindkey '^ ' autosuggest-accept"
      break
    fi
  done
fi

# === SYNTAX HIGHLIGHTING ===
# Load syntax highlighting if installed (cached path lookup, must be near the end)
_HIGHLIGHT_PATH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/syntax_highlight_path"
if [[ -f "$_HIGHLIGHT_PATH_CACHE" ]]; then
  _defer "source \"$(cat "$_HIGHLIGHT_PATH_CACHE")\""
else
  for highlight_file in /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
                        /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
                        ~/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    if [[ -f "$highlight_file" ]]; then
      echo "$highlight_file" > "$_HIGHLIGHT_PATH_CACHE"
      _defer "source \"$highlight_file\""
      break
    fi
  done
fi

# === PROMPT ===
# Starship prompt - Fast, cross-shell compatible (replaces P10k)
# Performance target: <40ms like P10k
if _has starship; then
  eval "$(starship init zsh)"
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
# GitHub Copilot CLI aliases (cached check)
if _has gh; then
  GH_COPILOT_CHECK="${XDG_CACHE_HOME:-$HOME/.cache}/gh_copilot_check"
  if [[ ! -f "$GH_COPILOT_CHECK"(#qNmh-168) ]]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
    if gh extension list 2>/dev/null | grep -q -E '(^|/)copilot($|[\s:])'; then
      : >| "$GH_COPILOT_CHECK"
    else
      rm -f "$GH_COPILOT_CHECK" 2>/dev/null
    fi
  fi
  [[ -f "$GH_COPILOT_CHECK" ]] && eval "$(gh copilot alias -- zsh 2>/dev/null)"
fi

# === PERFORMANCE DEBUG (optional) ===
# Uncomment to measure startup time
# if [[ -n "$ZSH_STARTUP_TIME" ]]; then
#   zprof
# fi
