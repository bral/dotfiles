# High-Performance Dotfiles

A "Formula 1" grade shell configuration focused on instant startup (<30ms), reliability, and AI integration.

## ⚡ Philosophy

- **Speed is a Feature**: Startup time is strictly budgeted (<30ms). Code is compiled (`zcompile`) and heavy initializations are cached.
- **Native over Frameworks**: No Zsh4Humans (Z4H) or Oh My Zsh. Just pure Zsh + Homebrew.
- **Parallel Maintenance**: Updates run concurrently, not sequentially.
- **AI Native**: Built-in context generation and smart commit tools for LLM workflows.

## 🛠️ Components

### 1. Shell (`.zshrc` + Starship)
A hyper-optimized Zsh environment:
- **Prompt**: [Starship](https://starship.rs) (Cached binary execution).
- **Plugin Manager**: None. Plugins are loaded directly from Homebrew for speed.
- **Performance**:
  - `_cache_eval`: Caches `eval "$(cmd)"` outputs (direnv, zoxide, mise) for 24h.
  - `_defer`: Loads syntax highlighting and autosuggestions *after* the prompt appears.
  - `zcompile`: Auto-compiles `.zshrc` to bytecode on change.
- **Features**:
  - **Magic Enter**: Press `Enter` on an empty line to run `ls` (or `git status` in repos).
  - **Universal Extract**: `x <file>` extracts any archive format.
  - **Copilot Integration**: Cached GitHub Copilot CLI aliases.

### 2. Window Management (Hammerspoon)
An event-driven window manager (`hammerspoon_init.lua`):
- **Zero Latency**: `animationDuration = 0` for instant snapping.
- **Event-Driven Focus**: Eliminates `usleep` delays by listening for macOS app activation events.
- **Hyper Key**: `Cmd+Alt+Ctrl+Shift` mapped to window movements and app switching.
  - `Hyper + Arrows`: Snap Left/Right/Up/Down.
  - `Hyper + Letter`: Instant app switch (e.g., `Hyper+F` for Browser).
  - `Hyper + 8`: Diagnostics (Check Bundle IDs).

### 3. System Updates (`bin/update-system`)
A parallelized update orchestrator. Run `up` to start.
- **Parallel Execution**: Runs Homebrew, Mise, and Go installs simultaneously.
- **Fail-Safe**: One failure (e.g., a Go package) won't stop the rest of the update.
- **Modules**:
  - `brew`: System packages & casks.
  - `mise`: Runtimes (Node, Python, Go, Rust).
  - `pipx`: Isolated Python CLIs.
  - `go`: Binary tools (Fabric, GoFast).
  - `spacevim`: Editor plugins (headless update).

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
cd <partial>         # Smart jump (zoxide)
..                   # Up one level
...                  # Up two levels
l / ll               # ls replacement (eza)
x <file>             # Extract archive

# Git
ga .                 # git add .
gc "msg"             # git commit
gp                   # git push
gst                  # git status
ai-commit            # Generate AI commit message

# System
up                   # Full parallel update
upquick              # Fast update (Brew + Mise only)
reload               # Reload shell configuration
```

### Hammerspoon Hotkeys

  - **Hyper + Return**: Maximize
  - **Hyper + Space**: Center
  - **Hyper + Arrow**: Split 50%
  - **Hyper + R**: Reload Config

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
