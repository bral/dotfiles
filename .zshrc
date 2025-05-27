# Performance monitoring
zmodload zsh/datetime
typeset -g SHELL_START_TIME=$EPOCHREALTIME

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r ~/.cache/p10k-instant-prompt-${(%):-%n}.zsh ]]; then
  source ~/.cache/p10k-instant-prompt-${(%):-%n}.zsh
fi

# Documentation: https://github.com/romkatv/zsh4humans/blob/v5/README.md

# Z4H Configuration
zstyle ':z4h:' auto-update      'no'
zstyle ':z4h:' auto-update-days '1'
zstyle ':z4h:bindkey' keyboard  'mac'
zstyle ':z4h:' start-tmux 'no'
zstyle ':z4h:' term-shell-integration 'yes'
zstyle ':z4h:' prompt-at-bottom 'yes'
zstyle ':z4h:autosuggestions' forward-char 'accept'
zstyle ':z4h:fzf-complete' recurse-dirs 'no'
zstyle ':z4h:direnv' enable 'yes'
zstyle ':z4h:direnv:success' notify 'yes'

# Install zsh-defer
z4h install romkatv/zsh-defer || return

# Initialize Z4H
z4h init || return

# Load zsh-defer
z4h load romkatv/zsh-defer

# Safe zsh compilation function (runs once per day)
_safe_zsh_compile() {
  local compile_marker="$HOME/.zsh_last_compile"
  local today=$(date +%Y%m%d)

  # Only compile if marker doesn't exist or is older than today
  if [[ ! -f "$compile_marker" ]] || [[ "$(<$compile_marker 2>/dev/null)" != "$today" ]]; then
    {
      [[ ! -e ~/.zshrc.zwc || ~/.zshrc -nt ~/.zshrc.zwc ]] && zcompile ~/.zshrc
      [[ -f ~/.env.zsh && (! -e ~/.env.zsh.zwc || ~/.env.zsh -nt ~/.env.zsh.zwc) ]] && zcompile ~/.env.zsh
      [[ -f ~/.secrets.zsh && (! -e ~/.secrets.zsh.zwc || ~/.secrets.zsh -nt ~/.secrets.zsh.zwc) ]] && zcompile ~/.secrets.zsh
      [[ -f ~/.zsh_paths_static && (! -e ~/.zsh_paths_static.zwc || ~/.zsh_paths_static -nt ~/.zsh_paths_static.zwc) ]] && zcompile ~/.zsh_paths_static
      echo "$today" > "$compile_marker"
    } 2>/dev/null
  fi
}

# Defer compilation check
zsh-defer _safe_zsh_compile

# ==== IMMEDIATE CRITICAL SETTINGS ====
export MISE_NODE_COREPACK=true # Allow corepack to manage pnpm and npm

# Only activate commonly used languages immediately, defer others
eval "$(~/.local/bin/mise activate zsh --shims)"

# Setup lazy loading for mise-managed tools
_load_mise_env() {
  eval "$(~/.local/bin/mise activate zsh)"
}
zsh-defer _load_mise_env

# Initialize zoxide for smart directory navigation
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Enhanced FZF configuration for better fuzzy finding
if command -v fzf >/dev/null 2>&1; then
  # FZF default options for better appearance and functionality
  export FZF_DEFAULT_OPTS="
    --height=50%
    --layout=reverse
    --border
    --preview-window=right:50%:wrap
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-u:preview-page-up'
    --bind='ctrl-d:preview-page-down'
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6ac,pointer:#f5e0dc
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6ac,hl+:#f38ba8"

  # Use fd for file searching if available, otherwise fallback to find
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  else
    export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/\.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='find . -type d -not -path "*/\.git/*"'
  fi

  # File preview with bat or cat
  if command -v bat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  else
    export FZF_CTRL_T_OPTS="--preview 'head -500 {}'"
  fi

  # Directory preview with tree or ls
  if command -v tree >/dev/null 2>&1; then
    export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
  else
    export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
  fi
fi

# Allow unmatched patterns
setopt +o nomatch

# Enhanced history configuration
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY        # Record timestamp of command
setopt HIST_EXPIRE_DUPS_FIRST  # Delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt HIST_IGNORE_DUPS        # Ignore duplicated commands history list
setopt HIST_IGNORE_SPACE       # Ignore commands that start with space
setopt HIST_VERIFY             # Show command with history expansion to user before running it
setopt INC_APPEND_HISTORY      # Add commands to HISTFILE in order of execution
setopt SHARE_HISTORY           # Share command history data between sessions

# Ensure unique entries in path
typeset -U path

# Define critical path components first
path=(
    $HOME/.local/bin        # Local user binaries
    $path                   # Existing system paths
)

# Export critical env vars immediately
export GPG_TTY=$TTY

# ==== PATH AND ENVIRONMENT SETUP ====

# Source static path/env setup for instant startup
[[ -f "$HOME/.zsh_paths_static" ]] && source "$HOME/.zsh_paths_static"

# Source environment and secrets if present
[[ -f "$HOME/.env.zsh" ]] && z4h source "$HOME/.env.zsh"
[[ -f "$HOME/.secrets.zsh" ]] && source "$HOME/.secrets.zsh"

# ==== DEFER KEY BINDINGS ====

# Create a simple function for key bindings
function _setup_keys() {
    z4h bindkey undo Ctrl+/   Shift+Tab
    z4h bindkey redo Option+/
    z4h bindkey z4h-cd-back    Shift+Left
    z4h bindkey z4h-cd-forward Shift+Right
    z4h bindkey z4h-cd-up      Shift+Up
    z4h bindkey z4h-cd-down    Shift+Down

    # Autoload functions
    autoload -Uz zmv

    # Define functions
    function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
    compdef _directories md

    # Named directories
    [[ -n "$z4h_win_home" ]] && hash -d w="$z4h_win_home"
}

# Defer key bindings setup
zsh-defer _setup_keys

# ==== DEFER ALIASES ====

# Create a simple function for aliases
function _setup_aliases() {
    # General aliases
    alias tree="tree -a -I .git"
    alias ..="cd .."
    alias p="pbpaste"
    alias asdf="mise"
    alias ff="fastfetch"
    alias v="nvim"
    alias tm="task-master" -- AI assisted project management CLI

    # Smart directory navigation with zoxide
    if command -v zoxide >/dev/null 2>&1; then
        alias cd="z"
        alias cdi="zi"  # Interactive directory selection
    fi

    # Enhanced history search and management
    if command -v fzf >/dev/null 2>&1; then
        # Search history with fzf
        alias h="history | fzf --tac --no-sort"
        alias hg="history | grep"

        # Custom history search function
        fh() {
            print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -E 's/ *[0-9]*\*? *//' | sed -E 's/\\/\\\\/g')
        }

        # Search and execute from history
        fhe() {
            eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed -E 's/ *[0-9]*\*? *//' | sed -E 's/\\/\\\\/g')
        }
    fi

    # LSD aliases
    alias l="lsd -lah"
    alias ll="lsd -lh"

    # Git aliases
    alias ga="git add"
    alias gb="git branch"
    alias gbd="git-branch-delete"
    alias gc="git commit"
    alias gco="git checkout"
    alias gcm="git commit -m"
    alias gd="git diff"
    alias gf="git fetch --all"
    alias gl="git log --oneline"
    alias gp="git push"
    alias gpl="git pull"
    alias gs="git status"
    alias gst="git stash"
    alias gstp="git stash pop"

    # Enhanced git workflow functions
    # Git status with enhanced formatting
    gss() {
        echo "📊 Repository Status:"
        git status --short --branch
        echo "\n🌿 Recent commits:"
        git log --oneline -5
        echo "\n📋 Working directory:"
        git diff --stat
    }

    # Interactive branch checkout with fzf
    if command -v fzf >/dev/null 2>&1; then
        gbb() {
            local branches branch
            branches=$(git branch --all | grep -v HEAD) &&
            branch=$(echo "$branches" | fzf-tmux -d 15 +m) &&
            git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
        }

        # Interactive git log with fzf
        glg() {
            git log --graph --color=always \
                --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
            fzf --ansi --no-sort --reverse --tiebreak=index \
                --preview 'echo {} | grep -o "[a-f0-9]\{7\}" | head -1 | xargs git show --color=always' \
                --bind "ctrl-m:execute:(echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs git show --color=always | less -R)"
        }
    fi

    # Smart git add - stage files interactively
    gai() {
        if command -v fzf >/dev/null 2>&1; then
            git status --porcelain | fzf -m --preview 'git diff --color=always {2}' | awk '{print $2}' | xargs git add
        else
            git add -i
        fi
    }

    # Enhanced clipboard integration
    # Copy current directory path
    cpwd() { pwd | tr -d '\n' | pbcopy && echo "📋 Copied: $(pwd)" }

    # Copy file contents with syntax highlighting info
    cpf() {
        if [[ -f "$1" ]]; then
            cat "$1" | pbcopy
            echo "📋 Copied contents of: $1"
        else
            echo "❌ File not found: $1"
        fi
    }

    # Copy command output
    cpo() { "$@" | pbcopy && echo "📋 Copied output of: $*" }

    # Paste and execute (be careful!)
    pex() {
        echo "⚠️  About to execute from clipboard:"
        pbpaste
        echo "\n❓ Continue? (y/N)"
        read -r confirm
        [[ "$confirm" = "y" ]] && eval "$(pbpaste)"
    }

    # Project management helpers
    # Quick project switcher with fzf
    proj() {
        local project_dirs=("$HOME/projects" "$HOME/dev" "$HOME/work" "$HOME/code")
        local found_dirs=()

        # Find existing project directories
        for dir in "${project_dirs[@]}"; do
            [[ -d "$dir" ]] && found_dirs+=("$dir")
        done

        if [[ ${#found_dirs[@]} -eq 0 ]]; then
            echo "❌ No project directories found. Create ~/projects, ~/dev, ~/work, or ~/code"
            return 1
        fi

        if command -v fzf >/dev/null 2>&1; then
            local project=$(find "${found_dirs[@]}" -maxdepth 2 -type d -name ".git" | \
                          sed 's|/.git||' | \
                          fzf --preview 'ls -la {} && echo "\n📊 Git status:" && git -C {} status --short 2>/dev/null || echo "Not a git repo"')
            [[ -n "$project" ]] && cd "$project"
        else
            echo "📁 Available project directories:"
            find "${found_dirs[@]}" -maxdepth 2 -type d -name ".git" | sed 's|/.git||' | nl
        fi
    }

    # Create new project with common structure
    newproj() {
        if [[ -z "$1" ]]; then
            echo "Usage: newproj <project-name>"
            return 1
        fi

        local project_dir="$HOME/projects/$1"
        mkdir -p "$project_dir"/{src,docs,tests}
        cd "$project_dir"

        # Initialize git if available
        if command -v git >/dev/null 2>&1; then
            git init
            echo "# $1\n\nProject created on $(date)" > README.md
            echo "node_modules/\n.env\n.DS_Store\n*.log" > .gitignore
            git add .
            git commit -m "Initial commit: project structure"
        fi

        echo "🎉 Created project: $1"
        echo "📍 Location: $project_dir"
    }


    # Add flags to existing aliases
    alias ls="${aliases[ls]:-ls} -A"

    # Compilation handled by _safe_zsh_compile function
}

# Comprehensive system update function with explained steps
function upa() {
    local start_time=$SECONDS
    echo "🚀 Starting comprehensive system update process..."

    # Phase 1: Homebrew
    upbrew

    # Phase 2: Development tools
    updev

    # Phase 3: CLI utilities
    echo "\n🧰 Updating CLI utilities..."
    echo "  ↳ Installing/updating fabric CLI tool via Go..."
    go install github.com/danielmiessler/fabric@latest
    echo "  ↳ Running fabric's self-update functionality..."
    fabric -U
    echo "  ↳ Installing/updating gofast CLI tool via Go..."
    go install github.com/gofast-live/gofast-cli/cmd/gofast@latest
    echo "  ↳ Self-updating crewai python env manager..."
    uv tool install crewai --upgrade

    # Phase 4: Neovim/SpaceVim
    upnvim

    # Phase 5: Terminal Enhancement Tools
    echo "\n🚀 Updating terminal enhancement tools..."
    echo "  ↳ Updating terminal productivity tools..."
    # Update fzf if installed via git
    if [[ -d "$HOME/.fzf" ]]; then
        cd "$HOME/.fzf" && git pull && ./install --all
        cd - > /dev/null
    fi
    # Update zoxide
    if command -v zoxide >/dev/null 2>&1; then
        echo "    ✓ zoxide managed by brew/mise"
    fi
    # Update other CLI tools via brew (bat, fd, tree, etc.)
    echo "    ✓ CLI tools (bat, fd, tree, lsd) managed by brew"

    # Phase 6: System Updates
    echo "\n🍎 Checking system updates..."
    echo "  ↳ Checking for macOS updates..."
    softwareupdate -l 2>/dev/null | grep -q "No new software available" && echo "    ✓ macOS is up to date" || echo "    ⚠️  macOS updates available - run 'softwareupdate -ia' manually"

    # Phase 7: Shell environment
    echo "\n🐚 Updating shell environment..."
    echo "🔄 Regenerating static path file..."
      {
        GOROOT="$(mise where go 2>/dev/null || echo '')"
        echo "export GOROOT=\"$GOROOT\""
        echo "export GOPATH=\"$HOME/go\""
        [[ -d "$HOME/go/bin" ]] && echo "path+=(\"$HOME/go/bin\")"
        [[ -n "$GOROOT" && -d "$GOROOT/bin" ]] && echo "path+=(\"$GOROOT/bin\")"
        brew_prefix=$(brew --prefix 2>/dev/null)
        [[ -n "$brew_prefix" && -d "$brew_prefix/bin" ]] && echo "path+=(\"$brew_prefix/bin\")"
        [[ -d "$HOME/bin" ]] && echo "path+=(\"$HOME/bin\")"

        # Homebrew PHP build vars
        brew_openssl=$(brew --prefix openssl 2>/dev/null)
        brew_libiconv=$(brew --prefix libiconv 2>/dev/null)
        brew_libzip=$(brew --prefix libzip 2>/dev/null)
        brew_bison=$(brew --prefix bison 2>/dev/null)
        brew_re2c=$(brew --prefix re2c 2>/dev/null)

        [[ -n "$brew_openssl" && -n "$brew_libiconv" ]] && \
          echo "export LDFLAGS=\"-L$brew_openssl/lib -L$brew_libiconv/lib\""
        [[ -n "$brew_openssl" && -n "$brew_libiconv" ]] && \
          echo "export CPPFLAGS=\"-I$brew_openssl/include -I$brew_libiconv/include\""
        [[ -n "$brew_openssl" && -n "$brew_libzip" ]] && \
          echo "export PKG_CONFIG_PATH=\"$brew_openssl/lib/pkgconfig:$brew_libzip/lib/pkgconfig:\$PKG_CONFIG_PATH\""
        [[ -n "$brew_bison" && -n "$brew_re2c" ]] && \
          echo "path+=(\"$brew_bison/bin\" \"$brew_re2c/bin\")"
          } > "$HOME/.zsh_paths_static"
    echo "✅ Static path file updated!"
    echo "  ↳ Compiling static path file for faster loading..."
    zcompile "$HOME/.zsh_paths_static"

    echo "  ↳ Updating zsh4humans framework..."
    z4h update

    # Phase 8: Cleanup
    echo "\n🧹 Cleaning up..."
    echo "  ↳ Cleaning npm cache..."
    npm cache clean --force 2>/dev/null || echo "    ⚠️  npm cache clean skipped"
    echo "  ↳ Cleaning pnpm cache..."
    pnpm store prune 2>/dev/null || echo "    ⚠️  pnpm cache clean skipped"
    echo "  ↳ Removing old zsh compiled files..."
    find ~ -name "*.zwc" -mtime +30 -delete 2>/dev/null || true
    echo "  ↳ Clearing temporary files..."
    [[ -d "$HOME/.cache" ]] && find "$HOME/.cache" -type f -mtime +7 -delete 2>/dev/null || true

    # Phase 9: Summary
    echo "\n✅ System update completed successfully!"
    echo ""
    echo "📊 Updated components:"
    echo "  • Homebrew packages and definitions"
    echo "  • Development tools (mise, corepack, pnpm, pip)"
    echo "  • CLI utilities (fabric, gofast, crewai)"
    echo "  • Neovim/SpaceVim framework and plugins"
    echo "  • Terminal enhancement tools"
    echo "  • Shell environment and static paths"
    echo "  • System cleanup completed"
    echo ""
    echo "💡 Next steps:"
    echo "  • Restart your terminal for optimal performance"
    echo "  • Check for macOS updates: softwareupdate -l"
    echo "  • Run 'zsh-bench' to measure performance improvements"
    echo ""
    echo "⏱️  Update completed in $((SECONDS - start_time))s"
}

# Individual update functions for specific components
function upnvim() {
    echo "🔧 Updating Neovim and SpaceVim..."
    if [[ -d "$HOME/.SpaceVim" ]]; then
        cd "$HOME/.SpaceVim" && git pull origin master
        cd - > /dev/null
        echo "  ↳ Updating SpaceVim plugins..."
        nvim +SPUpdate +qall 2>/dev/null || echo "    ⚠️  SpaceVim plugin update skipped (nvim not available)"
        echo "✅ Neovim/SpaceVim update completed!"
    else
        echo "❌ SpaceVim not found"
    fi
}

function updev() {
    echo "🔧 Updating development tools..."
    echo "  ↳ Upgrading mise-managed tools..."
    mise upgrade
    echo "  ↳ Self-updating mise..."
    mise self-update -y
    echo "  ↳ Updating corepack tools..."
    corepack up
    echo "  ↳ Updating global pnpm packages..."
    pnpm update -g
    echo "  ↳ Upgrading pip..."
    pip install --upgrade pip
    echo "✅ Development tools update completed!"
}

function upbrew() {
    echo "📦 Updating Homebrew..."
    echo "  ↳ Updating package definitions..."
    brew update
    echo "  ↳ Upgrading packages..."
    brew upgrade
    echo "  ↳ Cleaning up..."
    brew cleanup
    echo "✅ Homebrew update completed!"
}

function upquick() {
    echo "⚡ Quick system update..."
    brew update && brew upgrade
    mise upgrade
    pnpm update -g
    echo "✅ Quick update completed!"
}

function upcheck() {
    echo "🔍 Checking for available updates..."
    echo "\n📦 Homebrew:"
    brew outdated | head -5
    echo "\n🔧 mise:"
    mise outdated 2>/dev/null | head -5 || echo "  No outdated tools found"
    echo "\n🐍 pnpm global:"
    pnpm outdated -g 2>/dev/null | head -5 || echo "  No outdated packages found"
    echo "\n🍎 macOS:"
    softwareupdate -l 2>/dev/null | grep -q "No new software available" && echo "  ✓ Up to date" || echo "  Updates available"
}

# Defer aliases setup
zsh-defer _setup_aliases

# ==== IMPROVED LAZY LOADING FOR FABRIC ====

# More efficient fabric lazy loading with nocorrect handling
function fabric() {
    unfunction fabric
    if [[ -f "$HOME/.config/fabric/fabric-bootstrap.inc" ]]; then
        . "$HOME/.config/fabric/fabric-bootstrap.inc"
    fi
    command fabric "$@"
}
# Prevent autocorrection for fabric
alias fabric="nocorrect fabric"

# ==== SET SHELL OPTIONS ====

# These are lightweight and can stay immediate
setopt glob_dots     # no special treatment for file names with a leading dot
setopt no_auto_menu  # require an extra TAB press to open the completion menu

# Display startup time when shell is ready
zsh-defer -c 'if [[ -n "$SHELL_START_TIME" ]]; then
    typeset -g SHELL_READY_TIME=$EPOCHREALTIME
    echo "Shell startup time: $((($SHELL_READY_TIME - $SHELL_START_TIME) * 1000)) ms"
fi'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
