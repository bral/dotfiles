#!/usr/bin/env zsh
# FZF-Powered Git Functions
# Enhanced interactive git operations using fzf
# Add to your .zshrc or source from a separate file

# === CORE CONFIGURATION ===
# FZF git-specific options (Dracula theme)
# FZF git options as an array (avoids word-splitting issues)
# Colors must be quoted to prevent # from being interpreted as glob/comment
typeset -a FZF_GIT_OPTS=(
  --height=80%
  --layout=reverse
  --border=rounded
  --info=inline
  --preview-window=right:60%:wrap
  --bind=ctrl-/:toggle-preview
  --bind=ctrl-u:preview-page-up
  --bind=ctrl-d:preview-page-down
  '--bind=ctrl-y:execute-silent(echo -n {+} | pbcopy)'
  '--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9'
  '--color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9'
  '--color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6'
  '--color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
)

# === BRANCH OPERATIONS ===

# Interactive branch checkout with preview
# Shows all branches (local + remote) with commit preview
fzf-git-branch() {
  # Check if we're in a git repo
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local branches branch
  branches=$(git branch --all --color=always | command grep -v HEAD) || return

  branch=$(echo "$branches" |
    fzf --ansi \
        --no-multi \
        --prompt="Branch> " \
        --header="Enter: checkout | Ctrl-/: toggle preview | Ctrl-Y: copy name" \
        --preview="branch=\$(echo {} | perl -pe 's/\e\[[0-9;]*m//g' | sed 's/^[* ]*//' | sed 's#remotes/origin/##' | awk '{print \$1}'); [[ -n \"\$branch\" ]] && git log --oneline --graph --color=always --date=short --pretty='format:%C(auto)%cd %h%d %s' \"\$branch\" 2>/dev/null | head -50 || echo 'Select a branch'" \
        ${FZF_GIT_OPTS[@]}) || return

  # Clean up branch name (remove markers, spaces, remotes prefix, ANSI codes)
  branch=$(echo "$branch" | perl -pe 's/\e\[[0-9;]*m//g' | sed 's/^[* ]*//' | sed 's#remotes/origin/##' | awk '{print $1}')
  
  if [[ -n "$branch" ]]; then
    echo "Checking out: $branch"
    git checkout "$branch"
  fi
}

# Interactive branch deletion (local only)
# Multi-select with confirmation
# Shows merged status: ✓ = merged (safe to delete), blank = not merged
fzf-git-branch-delete() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local branches current_branch merged unmerged
  current_branch=$(git branch --show-current)

  # Get merged and unmerged branches separately with visual indicators
  # ✓ = merged into current branch (safe to delete)
  # (blank) = not merged (may lose work)
  # Excludes: current branch (^\*), main, master
  # Note: Using command grep to bypass any rg alias
  merged=$(git branch --merged | command grep -v "^\*" | command grep -v "^  main$" | command grep -v "^  master$" | sed 's/^  /✓ /')
  unmerged=$(git branch --no-merged | command grep -v "^\*" | command grep -v "^  main$" | command grep -v "^  master$" | sed 's/^  /  /')

  # Combine: merged first (safer to delete), then unmerged
  branches=$(printf "%s\n%s" "$merged" "$unmerged" | command grep -v '^$')

  if [[ -z "$branches" ]]; then
    echo "✓ No other local branches to delete"
    return 0
  fi

  local selected
  selected=$(echo "$branches" |
    fzf \
        --multi \
        --prompt="Delete branches (Tab to select)> " \
        --header="✓ = merged (safe) | Tab: select | Enter: delete" \
        --preview="branch=\$(echo {} | sed 's/^[✓ ]* //'); git log --oneline --graph --color=always --date=short --pretty='format:%C(auto)%cd %h%d %s' \"\$branch\" 2>/dev/null | head -50" \
        ${FZF_GIT_OPTS[@]}) || return

  if [[ -z "$selected" ]]; then
    echo "No branches selected"
    return 0
  fi

  # Show what will be deleted
  echo "\n📋 Branches to delete:"
  echo "$selected" | sed 's/^/  /'
  echo ""

  read -q "REPLY?Delete these branches? (y/N) "
  echo ""

  if [[ "$REPLY" == "y" ]]; then
    echo "$selected" | while IFS= read -r line; do
      # Strip the merged indicator (✓ or spaces) to get branch name
      local branch=$(echo "$line" | sed 's/^[✓ ]* //')
      echo "Deleting: $branch"
      git branch -d "$branch" 2>&1 | sed 's/^/  /'
    done
    echo "✓ Done"
  else
    echo "Cancelled"
  fi
}

# Create and checkout new branch from selected base
fzf-git-branch-new() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  # Get branch name from user
  echo -n "New branch name: "
  read new_branch
  
  if [[ -z "$new_branch" ]]; then
    echo "✗ Branch name required"
    return 1
  fi

  # Select base branch
  local branches base_branch
  branches=$(git branch --all --color=always | command grep -v HEAD) || return

  base_branch=$(echo "$branches" |
    fzf --ansi \
        --no-multi \
        --prompt="Base branch> " \
        --header="Select base branch for '$new_branch'" \
        --preview="branch=\$(echo {} | perl -pe 's/\e\[[0-9;]*m//g' | sed 's/^[* ]*//' | sed 's#remotes/origin/##' | awk '{print \$1}'); [[ -n \"\$branch\" ]] && git log --oneline --graph --color=always --date=short --pretty='format:%C(auto)%cd %h%d %s' \"\$branch\" 2>/dev/null | head -50 || echo 'Select a branch'" \
        ${FZF_GIT_OPTS[@]}) || return

  base_branch=$(echo "$base_branch" | perl -pe 's/\e\[[0-9;]*m//g' | sed 's/^[* ]*//' | sed 's#remotes/origin/##' | awk '{print $1}')
  
  if [[ -n "$base_branch" ]]; then
    echo "Creating branch '$new_branch' from '$base_branch'"
    git checkout -b "$new_branch" "$base_branch"
  fi
}

# === COMMIT OPERATIONS ===

# Interactive commit browser with detailed preview
fzf-git-log() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local commits
  commits=$(git log --oneline --color=always --decorate=short --all) || return

  git log --oneline --color=always --decorate=short --all |
    fzf --ansi \
        --no-multi \
        --prompt="Commit> " \
        --header="Enter: show details | Ctrl-Y: copy hash | Ctrl-/: toggle preview" \
        --preview="echo {} | awk '{print \$1}' | xargs git show --color=always --stat --patch" \
        --bind="enter:execute(echo {} | awk '{print \$1}' | xargs git show --color=always --stat --patch | less -R)" \
        ${FZF_GIT_OPTS[@]}
}

# Interactive commit cherry-pick
fzf-git-cherry-pick() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local commit
  commit=$(git log --oneline --color=always --decorate=short --all |
    fzf --ansi \
        --no-multi \
        --prompt="Cherry-pick> " \
        --header="Select commit to cherry-pick" \
        --preview="echo {} | awk '{print \$1}' | xargs git show --color=always --stat --patch" \
        ${FZF_GIT_OPTS[@]}) || return

  local hash=$(echo "$commit" | awk '{print $1}')
  
  if [[ -n "$hash" ]]; then
    echo "Cherry-picking: $hash"
    git cherry-pick "$hash"
  fi
}

# Interactive rebase target selection
fzf-git-rebase() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local target
  target=$(git log --oneline --color=always --decorate=short |
    fzf --ansi \
        --no-multi \
        --prompt="Rebase onto> " \
        --header="Select commit to rebase onto" \
        --preview="echo {} | awk '{print \$1}' | xargs git show --color=always --stat" \
        ${FZF_GIT_OPTS[@]}) || return

  local hash=$(echo "$target" | awk '{print $1}')
  
  if [[ -n "$hash" ]]; then
    echo "Rebasing onto: $hash"
    read -q "REPLY?Start interactive rebase? (y/N) "
    echo ""
    if [[ "$REPLY" == "y" ]]; then
      git rebase -i "$hash"
    fi
  fi
}

# === FILE OPERATIONS ===

# Interactive file staging (add)
fzf-git-add() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local files
  files=$(git status --short | command grep -E '^\?\?|^ M|^ D|^M |^D |^A ' | awk '{print $2}') || {
    echo "✓ No unstaged changes"
    return 0
  }

  local selected
  selected=$(echo "$files" |
    fzf --multi \
        --prompt="Stage files (Tab to select multiple)> " \
        --header="Tab: select | Enter: stage | Ctrl-/: toggle preview" \
        --preview="
          if [[ -f {} ]]; then
            git diff --color=always {} 2>/dev/null || bat --color=always --style=plain {} 2>/dev/null || cat {}
          else
            echo 'File deleted or binary'
          fi
        " \
        ${FZF_GIT_OPTS[@]}) || return

  if [[ -n "$selected" ]]; then
    echo "$selected" | while IFS= read -r file; do
      echo "Staging: $file"
      git add "$file"
    done
    echo "✓ Done"
    git status --short
  fi
}

# Interactive file unstaging (reset)
fzf-git-reset() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local files
  files=$(git diff --cached --name-only) || {
    echo "✓ No staged changes"
    return 0
  }

  local selected
  selected=$(echo "$files" |
    fzf --multi \
        --prompt="Unstage files (Tab to select multiple)> " \
        --header="Tab: select | Enter: unstage | Ctrl-/: toggle preview" \
        --preview="git diff --cached --color=always {}" \
        ${FZF_GIT_OPTS[@]}) || return

  if [[ -n "$selected" ]]; then
    echo "$selected" | while IFS= read -r file; do
      echo "Unstaging: $file"
      git reset HEAD "$file"
    done
    echo "✓ Done"
    git status --short
  fi
}

# Interactive file diff viewer
fzf-git-diff() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local files
  files=$(git status --short | awk '{print $2}') || {
    echo "✓ No changes"
    return 0
  }

  echo "$files" |
    fzf --no-multi \
        --prompt="Diff> " \
        --header="Select file to view diff | Enter: view in less" \
        --preview="git diff --color=always {} 2>/dev/null || git diff --cached --color=always {} 2>/dev/null || echo 'No diff available'" \
        --bind="enter:execute(git diff --color=always {} 2>/dev/null || git diff --cached --color=always {} | less -R)" \
        ${FZF_GIT_OPTS[@]}
}

# === STASH OPERATIONS ===

# Interactive stash browser and apply
fzf-git-stash() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local stashes
  stashes=$(git stash list) || {
    echo "✓ No stashes"
    return 0
  }

  local selected
  selected=$(echo "$stashes" |
    fzf --no-multi \
        --prompt="Stash> " \
        --header="Enter: apply | Ctrl-D: drop | Ctrl-P: pop | Ctrl-/: toggle preview" \
        --preview="echo {} | cut -d: -f1 | xargs git stash show -p --color=always" \
        --bind="ctrl-d:execute(echo {} | cut -d: -f1 | xargs git stash drop)+reload(git stash list)" \
        --bind="ctrl-p:execute(echo {} | cut -d: -f1 | xargs git stash pop)+abort" \
        ${FZF_GIT_OPTS[@]}) || return

  if [[ -n "$selected" ]]; then
    local stash_id=$(echo "$selected" | cut -d: -f1)
    echo "Applying: $stash_id"
    git stash apply "$stash_id"
  fi
}

# === REMOTE OPERATIONS ===

# Interactive remote branch tracking
fzf-git-track() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local remote_branches
  remote_branches=$(git branch -r | command grep -v HEAD | sed 's/^  //' | sed 's#origin/##') || return

  local selected
  selected=$(echo "$remote_branches" |
    fzf --no-multi \
        --prompt="Track remote branch> " \
        --header="Select remote branch to track locally" \
        --preview="git log --oneline --graph --color=always --date=short --pretty='format:%C(auto)%cd %h%d %s' origin/{} | head -50" \
        ${FZF_GIT_OPTS[@]}) || return

  if [[ -n "$selected" ]]; then
    echo "Creating local branch '$selected' tracking 'origin/$selected'"
    git checkout -b "$selected" "origin/$selected"
  fi
}

# Interactive remote viewer
fzf-git-remote() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local remotes
  remotes=$(git remote) || {
    echo "✓ No remotes configured"
    return 0
  }

  echo "$remotes" |
    fzf --no-multi \
        --prompt="Remote> " \
        --header="Select remote to view details" \
        --preview="git remote show {}" \
        --bind="enter:execute(git remote show {} | less)" \
        ${FZF_GIT_OPTS[@]}
}

# === TAG OPERATIONS ===

# Interactive tag browser and checkout
fzf-git-tag() {
  git rev-parse --git-dir > /dev/null 2>&1 || {
    echo "✗ Not a git repository"
    return 1
  }

  local tags
  tags=$(git tag --sort=-version:refname) || {
    echo "✓ No tags"
    return 0
  }

  local selected
  selected=$(echo "$tags" |
    fzf --no-multi \
        --prompt="Tag> " \
        --header="Enter: checkout | Ctrl-/: toggle preview | Ctrl-Y: copy name" \
        --preview="git show --color=always --stat {}" \
        ${FZF_GIT_OPTS[@]}) || return

  if [[ -n "$selected" ]]; then
    echo "Checking out tag: $selected"
    git checkout "$selected"
  fi
}

# === ALIASES ===
# Convenient short aliases for the functions above

alias gbb='fzf-git-branch'              # Branch checkout
alias gbd='fzf-git-branch-delete'       # Branch delete
alias gbn='fzf-git-branch-new'          # Branch new
alias gll='fzf-git-log'                 # Log viewer
alias gcp='fzf-git-cherry-pick'         # Cherry-pick
alias grb='fzf-git-rebase'              # Rebase
alias gaa='fzf-git-add'                 # Add files
alias grs='fzf-git-reset'               # Reset/unstage files
alias gdd='fzf-git-diff'                # Diff viewer
alias gss='fzf-git-stash'               # Stash browser
alias gtr='fzf-git-track'               # Track remote branch
alias grm='fzf-git-remote'              # Remote viewer
alias gtt='fzf-git-tag'                 # Tag browser

# === HELPER FUNCTION ===
# Show all available FZF git functions
fzf-git-help() {
  cat << 'EOF'
🚀 FZF-Powered Git Functions

BRANCH OPERATIONS:
  gbb  (fzf-git-branch)         - Interactive branch checkout
  gbd  (fzf-git-branch-delete)  - Interactive branch deletion (multi-select)
  gbn  (fzf-git-branch-new)     - Create new branch from selected base

COMMIT OPERATIONS:
  gll  (fzf-git-log)            - Interactive commit browser
  gcp  (fzf-git-cherry-pick)    - Interactive cherry-pick
  grb  (fzf-git-rebase)         - Interactive rebase target selection

FILE OPERATIONS:
  gaa  (fzf-git-add)            - Interactive file staging (multi-select)
  grs  (fzf-git-reset)          - Interactive file unstaging (multi-select)
  gdd  (fzf-git-diff)           - Interactive diff viewer

STASH OPERATIONS:
  gss  (fzf-git-stash)          - Interactive stash browser (apply/pop/drop)

REMOTE OPERATIONS:
  gtr  (fzf-git-track)          - Track remote branch locally
  grm  (fzf-git-remote)         - Remote details viewer

TAG OPERATIONS:
  gtt  (fzf-git-tag)            - Interactive tag browser and checkout

KEYBOARD SHORTCUTS (in FZF):
  Tab        - Select multiple items (where applicable)
  Enter      - Confirm selection
  Ctrl-/     - Toggle preview window
  Ctrl-U     - Preview page up
  Ctrl-D     - Preview page down
  Ctrl-Y     - Copy to clipboard
  Esc        - Cancel

TIPS:
  - All functions check if you're in a git repository
  - Preview windows show relevant git information
  - Multi-select functions use Tab for selection
  - Destructive operations require confirmation

Run 'fzf-git-help' anytime to see this help message.
EOF
}

alias ghelp='fzf-git-help'
