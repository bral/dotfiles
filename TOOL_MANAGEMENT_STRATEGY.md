# Tool Management Strategy: mise vs brew

## Current Reality (What's Actually Installed)

### 📦 BREW - System Tools & CLI Utilities
```
✓ bat              (better cat)
✓ fd               (better find)
✓ fzf              (fuzzy finder)
✓ gh               (GitHub CLI)
✓ git              (version control)
✓ jq               (JSON processor)
✓ lsd              (better ls)
✓ tree             (directory tree)
✓ zoxide           (smart cd)
```

### 🔧 MISE - Programming Languages & Runtimes
```
✓ bun              (JavaScript runtime)
✓ go               (Go language)
✓ java             (Java runtime)
✓ lua              (Lua language)
✓ neovim           (text editor) ← THIS IS YOUR nvim!
✓ node             (Node.js - multiple versions)
✓ pipx             (Python app installer)
✓ python           (Python - multiple versions)
✓ rust             (Rust language)
✓ uv               (Python package installer)
```

### ❌ MISSING ENTIRELY
```
✗ direnv           (environment switcher - used in .zshrc!)
```

---

## The Philosophy

### **BREW = System-level tools**
- Install once, use everywhere
- Single version (system-wide)
- Managed by Homebrew
- Examples: bat, fd, fzf, git, jq

**Why brew for these?**
- Don't need version management
- Want same version across all projects
- System utilities, not project dependencies

### **MISE = Programming environments**
- Multiple versions supported
- Per-project version switching
- Managed by mise
- Examples: node, python, go, rust, neovim

**Why mise for these?**
- Need different versions per project
- Project-specific .mise.toml files
- Version managers (like nvm, pyenv, rbenv unified)

---

## Your Current Setup Explained

### ✅ **CORRECTLY MANAGED:**

**Brew (system tools):**
- `bat`, `fd`, `fzf` - CLI utilities (don't need versions)
- `git`, `gh` - Version control (system-wide)
- `lsd`, `tree`, `zoxide` - Shell enhancements

**Mise (programming tools):**
- `node`, `python`, `go` - Need per-project versions
- `neovim` - You use latest version, but mise keeps it updated
- `bun`, `rust`, `uv` - Development tooling

### ❌ **MISSING:**

**direnv** - Should be installed via **BREW**
- It's a system tool (environment switcher)
- Doesn't need version management
- Used globally across projects

---

## Why mise for neovim?

**Advantages:**
```bash
mise install neovim@latest  # Always latest nightly
mise install neovim@0.10.0  # Or pin specific version
mise use neovim@latest      # Set globally
```

**vs Brew:**
```bash
brew install neovim  # Gets whatever brew has
brew upgrade neovim  # Manually upgrade
```

**Your choice (mise) allows:**
- Automatic updates via `mise upgrade`
- Pin to specific version if needed
- Consistent with other dev tools

---

## What install.sh SHOULD Do

### Current install.sh (line 169-178):
```bash
packages=(
    "zsh"
    "lsd"
    "bat"
    "fd"
    "fzf"
    "tree"
    "zoxide"
    "git"
)
```

### Recommended install.sh:
```bash
# BREW packages (system tools only)
packages=(
    "zsh"
    "git"
    "gh"           # ← ADD (GitHub CLI for .zshrc)
    "direnv"       # ← ADD (environment switcher for .zshrc)
    "lsd"
    "bat"
    "fd"
    "fzf"
    "tree"
    "zoxide"
    "jq"           # ← ADD (commonly used)
    "zsh-autosuggestions"      # ← ADD (zsh plugin)
    "zsh-syntax-highlighting"  # ← ADD (zsh plugin)
)

# MISE tools (programming languages)
# DON'T install in install.sh - user manages via ~/.config/mise/config.toml
# Already has: node, python, go, neovim, bun, rust, etc.
```

### Why NOT install mise tools in install.sh?

**User already has ~/.config/mise/config.toml:**
```toml
[tools]
node = "lts"
python = "latest"
go = "latest"
neovim = "latest"
bun = "latest"
rust = "latest"
# ... etc
```

**Just install mise itself, then:**
```bash
mise install  # Reads config.toml and installs everything
```

---

## Updated install.sh Strategy

### 1. Install Homebrew (already does this)
```bash
install_homebrew()
```

### 2. Install system tools via brew
```bash
packages=(
    "zsh"
    "git"
    "gh"
    "direnv"        # ← NEW
    "lsd"
    "bat"
    "fd"
    "fzf"
    "tree"
    "zoxide"
    "jq"            # ← NEW
    "zsh-autosuggestions"       # ← NEW
    "zsh-syntax-highlighting"   # ← NEW
)
```

### 3. Install mise (already does this via curl - but security issue!)
```bash
# Current (insecure):
curl https://mise.run | sh

# Better:
brew install mise  # ← MUCH SAFER!
```

### 4. Install mise tools from config
```bash
if command -v mise >/dev/null; then
    info "Installing mise tools from config.toml..."
    mise install
    mise upgrade
fi
```

**This reads ~/.config/mise/config.toml and installs:**
- node, python, go, neovim, bun, rust, etc.
- Already configured! Don't duplicate in install.sh.

---

## Answer to Your Question

**Q: How are these tools managed? mise? brew?**

**A: BOTH, with clear separation:**

### **BREW manages:**
- ✅ bat, fd, fzf (CLI utilities)
- ✅ git, gh (version control)
- ✅ lsd, tree, zoxide (shell tools)
- ✅ jq (data processing)
- ❌ direnv (MISSING - should add!)
- ❌ zsh plugins (MISSING - should add!)

### **MISE manages:**
- ✅ node, python, go (languages)
- ✅ neovim (your EDITOR via mise!)
- ✅ bun, rust (runtimes)
- ✅ uv, pipx (package managers)

### **NEITHER manages (but should):**
- direnv → should be **BREW**
- powerlevel10k → should be **BREW**
- zsh-autosuggestions → should be **BREW**
- zsh-syntax-highlighting → should be **BREW**

---

## Recommended Actions

### 1. Add to Brewfile:
```bash
brew "direnv"
brew "powerlevel10k"
```

### 2. Update install.sh packages array:
```bash
packages=(
    "zsh"
    "git"
    "gh"                         # ← ADD
    "direnv"                     # ← ADD
    "lsd"
    "bat"
    "fd"
    "fzf"
    "tree"
    "zoxide"
    "jq"                         # ← ADD
    "zsh-autosuggestions"        # ← ADD
    "zsh-syntax-highlighting"    # ← ADD
    "powerlevel10k"              # ← ADD
)
```

### 3. Replace mise curl install:
```bash
# OLD (insecure):
curl https://mise.run | sh

# NEW (secure):
brew install mise
```

### 4. Add mise tool installation:
```bash
# After installing mise:
if command -v mise >/dev/null; then
    info "Installing development tools via mise..."
    mise install    # Reads ~/.config/mise/config.toml
fi
```

### 5. Remove z4h setup (lines 200-269):
- It's broken
- Unnecessary (using brew for plugins now)
- Adds complexity

---

## Summary

**Your current setup is MOSTLY correct:**
- ✅ System tools via brew
- ✅ Programming languages via mise
- ✅ neovim via mise (not missing!)

**Only missing:**
- ❌ direnv (add to brew)
- ❌ zsh plugins (add to brew, remove z4h)

**Key insight:**
> neovim is NOT missing - it's installed via mise!
> Your EDITOR=nvim works because mise puts it in PATH.

**The confusion:**
- My earlier audit said "nvim missing"
- BUT it's in mise, not brew
- Both are valid, you chose mise (smart choice for version management)

---

## Final Tool Management Table

| Tool | Manager | Reason | Status |
|------|---------|--------|--------|
| bat | brew | CLI utility | ✅ Installed |
| fd | brew | CLI utility | ✅ Installed |
| fzf | brew | CLI utility | ✅ Installed |
| git | brew | System tool | ✅ Installed |
| gh | brew | System tool | ✅ Installed |
| direnv | brew | System tool | ❌ MISSING |
| jq | brew | CLI utility | ✅ Installed |
| lsd | brew | CLI utility | ✅ Installed |
| tree | brew | CLI utility | ✅ Installed |
| zoxide | brew | System tool | ✅ Installed |
| zsh-* plugins | brew | Shell plugins | ❌ MISSING |
| powerlevel10k | brew | Shell theme | ❌ MISSING |
| node | mise | Need versions | ✅ Installed |
| python | mise | Need versions | ✅ Installed |
| go | mise | Need versions | ✅ Installed |
| neovim | mise | Want latest | ✅ Installed |
| bun | mise | Need versions | ✅ Installed |
| rust | mise | Need versions | ✅ Installed |

**Total Missing: 3 (direnv + 2 zsh plugins)**

---

End of analysis.
