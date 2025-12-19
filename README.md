# High-Performance Dotfiles

A "Formula 1" grade shell configuration focused on instant startup (~18ms), reliability, and AI integration.

## ⚡ Philosophy

- **Speed is a Feature**: Startup time is strictly budgeted (~18ms). Uses "micro-kernel" deferred loading - heavy work runs in precmd, invisible to timing.
- **Native over Frameworks**: No Zsh4Humans (Z4H) or Oh My Zsh. Just pure Zsh + Homebrew.
- **Parallel Maintenance**: Updates run concurrently with animated progress indicators.
- **AI Native**: Built-in context generation and smart commit tools for LLM workflows.

## 🛠️ Components

### 1. Shell (`.zshrc` v3.1 + Starship)
A hyper-optimized Zsh environment with deferred loading architecture:
- **Prompt**: [Starship](https://starship.rs) (Cached binary execution).
- **Plugin Manager**: None. Plugins are loaded directly from Homebrew for speed.
- **Performance** (~18ms startup):
  - `_defer`: Moves compinit, fzf-tab, direnv, zoxide, starship to precmd (invisible to `hyperfine`).
  - `_cache_eval`: Caches tool init output for 7 days.
  - `zcompile`: Auto-compiles `.zshrc` to bytecode on change.
- **Features**:
  - **Safe-rm**: Protected rm blocks catastrophic patterns (e.g., `rm ~`) and suggests `trash`.
  - **Universal Extract**: `x <file>` extracts any archive format.
  - **Auto-list**: Directory contents shown after `cd`.

### 2. Window Management (Hammerspoon)
An event-driven window manager (`hammerspoon_init.lua`):
- **Zero Latency**: `animationDuration = 0` for instant snapping.
- **Event-Driven Focus**: Eliminates 120ms blind waits by listening for macOS activation events (45-150ms).
- **Mouse Centering**: Mouse moves to center of focused window automatically.
- **Hyper Key**: `Cmd+Alt+Ctrl+Shift` mapped to window movements and app switching.
  - `Hyper + Arrows`: Snap Left/Right/Up/Down.
  - `Hyper + Letter`: Instant app switch with window cycling.
  - `Hyper + 8`: Bundle ID checker, `Hyper + 9`: Diagnostics.

### 3. System Updates (`bin/update-system` v2.3)
A parallelized update orchestrator. Run `up` to start.
- **Animated Spinners**: Braille pattern animation (⣷⣯⣟⡿⢿⣻⣽⣾) with real-time status.
- **Parallel Execution**: Runs Homebrew, Mise, and Go installs simultaneously.
- **Fail-Safe**: One failure won't stop the rest of the update. Shows error logs for failed tasks.
- **Modules**:
  - `brew`: System packages & casks.
  - `mise`: Runtimes (Node, Python, Go, Rust).
  - `pipx`: Isolated Python CLIs.
  - `go`: Binary tools (Fabric, GoFast) with 5-min timeout.
  - `spacevim`: Editor plugins (headless update with 2-min timeout).

### 4. AI Workflows
Scripts designed to bridge the terminal with LLMs:
- **`bin/ai-context`**: Generates a context dump of the current project (Structure, Git status, Dependencies, TODOs) for pasting into LLMs.
- **`bin/fabric-helpers`**:
  - `ai-commit`: Stages changes and generates a conventional commit message using Fabric.
  - `smart-commit`: Generates a commit message preview without committing.
  - `doc-code <file>`: Generates documentation for a specific file.

## 🚀 Usage

### Daily Commands
```bash
# Navigation
z <partial>          # Smart jump (zoxide)
cdi                  # Interactive zoxide with fzf
..                   # Up one level
...                  # Up two levels
l / ll               # ls replacement (eza)
x <file>             # Extract archive
del <file>           # Move to Trash (recoverable)

# Git
ga .                 # git add .
gcm "msg"            # git commit -m
gp                   # git push
gs                   # git status
ai-commit            # Generate AI commit message

# System
up                   # Full parallel update (animated spinners)
up quick             # Fast update (Brew + Mise only)
up check             # See what needs updating
```

### Hammerspoon Hotkeys

  - **Hyper + Return**: Maximize window
  - **Hyper + Space**: Center window
  - **Hyper + Arrow**: Split 50% (Left/Right/Up/Down)
  - **Hyper + Letter**: Switch to app (I=Ghostty, V=VSCode, L=Superhuman, etc.)
  - **Hyper + R**: Reload config
  - **Hyper + 8**: Check bundle IDs
  - **Hyper + 9**: Diagnostics

## 📦 Installation

### Automated Install

```bash
git clone https://github.com/bral/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

This will:

1.  Symlink configuration files (`.zshrc`, `.zshenv`, `hammerspoon_init.lua`).
2.  Install Homebrew and Bundle dependencies (`Brewfile`).
3.  Setup `mise` runtimes.

### Dependencies

Managed via `Brewfile`. Key tools:

  - **Core**: `zsh`, `git`, `starship`, `direnv`, `mise`
  - **Utils**: `fzf`, `bat`, `eza` (ls replacement), `zoxide` (cd replacement), `jq`, `fd`
  - **AI**: `fabric`, `gh` (GitHub CLI)

## 🧩 Tool Management Strategy

We use a strict separation of concerns:

| Manager | Scope | Examples |
| :--- | :--- | :--- |
| **Homebrew** | System Binaries & CLIs | `git`, `nvim`, `fzf`, `starship` |
| **Mise** | Language Runtimes | `node`, `python`, `go`, `rust` |
| **Pipx** | Python CLIs | `poetry`, `black` |
| **Cargo/Go** | Language Specific Tools | `fabric`, `gofast` |

## 📂 File Structure

```
dotfiles/
├── .zshrc                  # Main shell config (Performance optimized)
├── .zshenv                 # Environment variables (XDG, Paths)
├── hammerspoon_init.lua    # Window management
├── Brewfile                # System dependencies
├── install.sh              # Idempotent installer
├── bin/
│   ├── update-system       # Parallel update script
│   ├── ai-context          # Context generator for LLMs
│   ├── fabric-helpers      # AI commit wrappers
│   └── optimize-vscode     # VSCode cleanup script
└── docs/                   # Documentation & Audits
```
