# Dotfiles Configuration

A clean, maintainable dotfiles setup focused on simplicity and reliability.

## Philosophy

- **Simple over complex**: No premature optimizations or over-engineering
- **Readable over clever**: Code that's easy to understand and modify
- **Separate concerns**: Shell config for shell things, scripts for complex logic
- **Standard tools**: Use well-established tools in their intended way

## Components

### Zsh Configuration (`.zshrc` + `.zshenv` + `.p10k.zsh`)

A clean, modern shell configuration with:

- **Z4H Framework**: Modern zsh setup with proper environment variables in `.zshenv`
- **Lean Powerlevel10k**: Minimal prompt style at top of terminal (not bottom)
- **Essential aliases**: Common shortcuts without bloat
- **Tool integration**: FZF, zoxide, mise for enhanced productivity
- **Git shortcuts**: Standard git aliases for daily workflow
- **History management**: Comprehensive history settings
- **Clean structure**: Logical organization, easy to modify
- **Corepack integration**: Uses Corepack for pnpm management (not Homebrew)

### Hammerspoon Configuration (`hammerspoon_init.lua`)

A window manager with:

- **App switching**: Hyper key + letter for instant app access
- **Window management**: Arrow keys for positioning, space/return for sizing
- **Error handling**: Graceful failures with user feedback
- **Bundle ID checker**: Hyper+8 to verify app configurations

### Update System (`bin/update-system`)

A comprehensive update script with:

- **Modular updates**: Separate functions for different components
- **Multiple modes**: Full, quick, check, and component-specific updates
- **Error handling**: Graceful failures and user feedback
- **Proper separation**: Complex logic outside of shell config
- **Corepack management**: Properly handles pnpm via Corepack (not Homebrew)
- **Smart conflict resolution**: Avoids package manager conflicts

## Usage

### Daily Commands

```bash
# Navigation
cd <partial-name>     # Smart directory jumping with zoxide
..                   # Go up one directory
l                    # List files with details
v <file>             # Open in neovim

# Git workflow
gs                   # Git status
ga <files>           # Git add
gcm "message"        # Git commit with message
gp                   # Git push
gpl                  # Git pull

# History search
h                    # Search history with FZF
fh                   # Select and insert from history

# Clipboard
cpwd                 # Copy current directory path
cpf <file>           # Copy file contents
```

### App Switching (Hammerspoon)

- **Hyper + Letter**: Switch to configured apps
- **Hyper + Arrows**: Position windows (left/right/up/down)
- **Hyper + Return**: Maximize window
- **Hyper + Space**: Center window
- **Hyper + 8**: Check bundle IDs
- **Hyper + 9**: Show diagnostics
- **Hyper + Y**: Toggle console
- **Hyper + R**: Reload configuration

### System Updates

```bash
up                   # Full system update
upquick              # Quick update (brew, mise, pnpm)
upcheck              # Check for available updates
upbrew               # Update Homebrew only
updev                # Update development tools only
```

## Installation

### Automated Installation (Recommended)

1. **Clone repository**:

   ```bash
   git clone <repo> ~/Projects/dotfiles
   cd ~/Projects/dotfiles
   ```

2. **Run install script**:
   ```bash
   ./install.sh
   ```

The install script will:

- Safely backup existing configurations
- Create symlinks for `.zshrc`, `.zshenv`, `.p10k.zsh`, and Hammerspoon config
- Install recommended dependencies via Homebrew
- Set up zsh4humans framework with proper environment variables
- Configure lean Powerlevel10k theme
- Make bin scripts executable
- Verify the installation

**Important**: After installation, restart your terminal for changes to take effect.

### Manual Installation

If you prefer manual setup:

```bash
# Create necessary directories
mkdir -p ~/.hammerspoon

# Link configurations (NOTE: Must be in ~/Projects/dotfiles for paths to work)
ln -sf ~/Projects/dotfiles/.zshrc ~/.zshrc
ln -sf ~/Projects/dotfiles/.zshenv ~/.zshenv
ln -sf ~/Projects/dotfiles/.p10k.zsh ~/.p10k.zsh
ln -sf ~/Projects/dotfiles/hammerspoon_init.lua ~/.hammerspoon/init.lua

# Install dependencies
brew install zsh lsd bat fd fzf tree zoxide
curl https://mise.run | sh

# DO NOT install pnpm via Homebrew - use Corepack instead
corepack enable
corepack prepare pnpm@latest --activate

# Install z4h (will be configured automatically)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
```

### Install Script Options

```bash
./install.sh --help      # Show help
./install.sh --verify    # Verify existing installation
./install.sh --deps      # Install dependencies only
./install.sh --uninstall # Remove all dotfiles symlinks
```

## Customization

### Adding Apps to Hammerspoon

Edit `hammerspoon_init.lua` and add to the `apps` table:

```lua
local apps = {
  -- Existing apps...
  X = "com.example.MyApp",  -- Find bundle ID with Hyper+8
}
```

### Adding Aliases

Edit `.zshrc` and add to the aliases section:

```bash
# Add your aliases here
alias myalias="my command"
```

### Modifying Updates

Edit `bin/update-system` to add or modify update routines.

## File Structure

```
dotfiles/
├── README.md                    # This file
├── install.sh                  # Automated installation script
├── .zshrc                      # Main shell configuration
├── .zshenv                     # Z4H environment variables (REQUIRED)
├── .p10k.zsh                   # Lean Powerlevel10k configuration
├── hammerspoon_init.lua        # Simple window manager
└── bin/
    ├── update-system           # Comprehensive update script
    └── repair-z4h              # Z4H corruption repair script
```

## Development Guidelines

### Critical Requirements

1. **Z4H Environment Variables**: The `Z4H_URL` and `Z4H` variables **MUST** be in `.zshenv` (not `.zshrc`). Z4H requires these before shell initialization.

2. **Repository Location**: Dotfiles **MUST** be in `~/Projects/dotfiles` because:
   - Update script paths are hardcoded to this location
   - Aliases reference this specific path
   - Changing location breaks functionality

3. **Package Manager Conflicts**: 
   - **Use Corepack for pnpm** (not Homebrew)
   - Never install pnpm via Homebrew as it conflicts with Corepack
   - Update script handles this correctly

4. **Z4H Installation**: The install script handles z4h setup non-interactively. Manual z4h installation may fail in automated environments.

5. **Z4H Corruption**: Z4H plugins can get corrupted during incomplete downloads. Use `bin/repair-z4h` to fix missing plugin files.

### Prompt Configuration

The lean prompt configuration provides:
- **Single-line prompt at top** (not bottom)
- **Minimal elements**: directory, git status, timing info
- **Clean aesthetic**: inspired by Pure shell theme
- **Customizable**: modify `.p10k.zsh` for different styles

### Troubleshooting

**"please use exec zsh instead of source ~/.zshenv"**: Missing Z4H environment variables in `.zshenv`

**Missing z4h files** (`no such file or directory: powerlevel10k.zsh-theme`): Z4H installation corrupted. Fix with:
```bash
~/Projects/dotfiles/bin/repair-z4h
# OR
~/Projects/dotfiles/install.sh
```

**pnpm conflicts**: Uninstall Homebrew pnpm and use Corepack: `brew uninstall pnpm && corepack enable`

**Corepack cache corruption** (`Cannot find module 'pnpm.cjs'`): Clear cache and reinstall:
```bash
rm -rf ~/.cache/node/corepack
corepack enable
corepack install -g pnpm@latest
```

**Update script fails**: Ensure repository is in `~/Projects/dotfiles`

## Migration Notes

This configuration is a simplified, reliable version that removes:

- Performance measurement theater
- Complex caching systems
- Over-engineered deferred loading
- Massive update functions in shell config
- FFI window management complexity
- Premature optimizations

All functionality is preserved while dramatically improving maintainability.

### Recent Fixes

- **Z4H Bootstrap**: Proper non-interactive installation that handles missing plugins
- **Z4H Repair**: Dedicated repair script for corrupted z4h installations
- **Environment Variables**: Correct placement in `.zshenv` for z4h compatibility
- **Lean Prompt**: Clean, minimal Powerlevel10k configuration
- **Package Management**: Corepack integration to avoid Homebrew conflicts
- **Corepack Cache**: Automatic corruption detection and cache clearing
- **Path Dependencies**: Hardcoded paths that require specific repository location

### Future Development

When modifying this configuration:

1. **Test z4h changes carefully** - Environment variable placement is critical
2. **Maintain repository location** - Many paths are hardcoded to `~/Projects/dotfiles`
3. **Avoid package manager conflicts** - Keep pnpm management with Corepack
4. **Use install script for testing** - It handles edge cases and proper bootstrap
5. **Monitor z4h corruption** - Plugin files can get corrupted during downloads
6. **Document breaking changes** - Update this README with any critical requirements
