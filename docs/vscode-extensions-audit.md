# VSCode Extensions Audit

**Total Extensions**: 49
**Audit Date**: 2025-10-31

## Recommendations

### ✅ Keep (Core Functionality)

**AI Tools** (3):
- `anthropic.claude-code` - Claude Code integration
- `openai.chatgpt` - ChatGPT integration
- `rooveterinaryinc.roo-cline` - Cline AI assistant

**Language Support** (Keep active languages):
- `golang.go` - Go support
- `ms-python.python`, `ms-python.vscode-pylance`, `ms-python.debugpy` - Python
- `svelte.svelte-vscode`, `ardenivanov.svelte-intellisense` - Svelte
- `astro-build.astro-vscode` - Astro
- `ms-vscode.vscode-typescript-next` - TypeScript

**Linting/Formatting** (5):
- `dbaeumer.vscode-eslint` - ESLint
- `charliermarsh.ruff` - Python linting (Ruff)
- `esbenp.prettier-vscode` - Prettier
- `editorconfig.editorconfig` - EditorConfig
- `ms-python.mypy-type-checker` - Python type checking

**Git Tools** (2):
- `eamodio.gitlens` - Git visualization
- `github.vscode-pull-request-github` - GitHub PRs

**Editor Enhancement** (4):
- `usernamehw.errorlens` - Inline errors
- `vscodevim.vim` - Vim keybindings
- `redhat.vscode-yaml` - YAML support
- `dracula-theme.theme-dracula` - Theme

### ⚠️ Review (Potential Duplicates)

**Docker** (Consider removing 1-2):
- `docker.docker` 
- `ms-azuretools.vscode-docker` ⚠️ DUPLICATE - Remove one
- `ms-azuretools.vscode-containers`
- `ms-vscode-remote.remote-containers` ⚠️ May be redundant

**Svelte** (2 extensions):
- `svelte.svelte-vscode` - Official, keep
- `ardenivanov.svelte-intellisense` ⚠️ May be redundant

**Python Tools** (5 Python-related):
- Core: `ms-python.python`, `ms-python.vscode-pylance` - Keep
- Debug: `ms-python.debugpy` - Keep
- Type check: `ms-python.mypy-type-checker` - Keep if using type checking
- Env: `ms-python.vscode-python-envs` - Keep

### ❌ Consider Removing (Low Usage/Redundant)

**Vim Workflow** (if not using):
- `vspacecode.vspacecode` - Spacemacs-like keybindings
- `vspacecode.whichkey` - Which-key for VSCode
- Only remove if not actively using Spacemacs workflow

**Git** (if not using):
- `kahole.magit` - Emacs-style git interface (redundant with GitLens?)

**Testing** (if not actively testing):
- `wallabyjs.quokka-vscode` - JavaScript playground (paid, $50-100/year)
- `orta.vscode-jest` - Jest runner (keep if using Jest)

**IntelliSense** (potential redundancy):
- `christian-kohler.npm-intellisense` - NPM package autocomplete
- `christian-kohler.path-intellisense` - Path autocomplete
- `visualstudioexptteam.intellicode-api-usage-examples` - AI suggestions
- `visualstudioexptteam.vscodeintellicode` - IntelliCode

**Other**:
- `bodil.file-browser` - File browser (if not using)
- `jacobdufault.fuzzy-search` - Fuzzy search (redundant with built-in?)
- `wix.vscode-import-cost` - Import cost display (performance impact)
- `oderwat.indent-rainbow` - Rainbow indents (visual noise?)
- `aaron-bond.better-comments` - Comment highlighting
- `mikestead.dotenv` - .env syntax (minimal value)
- `ms-vsliveshare.vsliveshare` - Live Share (if not collaborating)
- `traycer.traycer-vscode` - Not sure what this is

## Cleanup Commands

```bash
# Remove Docker duplicate
code --uninstall-extension ms-azuretools.vscode-docker

# Remove potential redundancies (review first!)
code --uninstall-extension bodil.file-browser
code --uninstall-extension jacobdufault.fuzzy-search
code --uninstall-extension wix.vscode-import-cost
code --uninstall-extension oderwat.indent-rainbow
code --uninstall-extension mikestead.dotenv
code --uninstall-extension ms-vsliveshare.vsliveshare

# Remove if not using Quokka (paid)
code --uninstall-extension wallabyjs.quokka-vscode

# Remove if not using Spacemacs workflow
code --uninstall-extension vspacecode.vspacecode
code --uninstall-extension vspacecode.whichkey

# Remove if not using magit
code --uninstall-extension kahole.magit
```

## Total Extensions After Cleanup

**Before**: 49 extensions
**After**: ~35-40 extensions (remove 9-14 redundant/unused)

## Notes

- Keep language-specific extensions for languages you actively use
- Consider removing Quokka if not using (paid extension)
- Docker extensions have duplicates - keep docker.docker or ms-azuretools.vscode-docker
- Review Vim/Spacemacs extensions - keep only if actively using that workflow
- Import Cost can slow down the editor with large files
