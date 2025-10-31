# Smart Commit Guide - AI-Powered Git Commits

**How to use the Fabric-powered commit message generator**

---

## 🚀 Quick Start (Most Common)

### Option 1: Interactive AI Commit (Recommended)

```bash
# 1. Stage your changes
git add .

# 2. Run ai-commit (generates message + asks for confirmation)
ai-commit
```

**What happens:**
1. Analyzes your staged changes
2. Generates conventional commit message
3. Shows you the message
4. Asks: "Commit with this message? [y/N]"
5. If yes → commits automatically
6. If no → cancels (changes stay staged)

---

## 📖 All Available Commands

### 1. `ai-commit` - Full Interactive Experience

**Use when**: You want to commit with AI-generated message

```bash
# Stage changes first
git add file1.js file2.js

# Generate message and commit interactively
ai-commit
```

**Output Example**:
```
Generating commit message...

=== Generated Commit Message ===
feat(auth): add JWT token refresh mechanism

Implement automatic token refresh to prevent session expiry.
Users will now seamlessly maintain their session without
re-authentication.
================================

Commit with this message? [y/N] y
✅ Committed successfully!
```

---

### 2. `smart-commit` - Just Generate Message

**Use when**: You want to see the message but commit manually

```bash
# Stage changes
git add .

# Generate message (doesn't commit)
smart-commit
```

**Output**:
```
feat(auth): add JWT token refresh mechanism

Implement automatic token refresh to prevent session expiry.
```

**Then commit manually** if you like it:
```bash
git commit -m "$(smart-commit)"
```

---

### 3. Direct Fabric Pattern

**Use when**: You want full control

```bash
# Generate message from staged changes
git diff --cached | fabric --pattern smart_commit_message

# Or save to variable
MESSAGE=$(git diff --cached | fabric --pattern smart_commit_message)
git commit -m "$MESSAGE"
```

---

## 🎯 Complete Workflow Examples

### Example 1: Feature Development

```bash
# Work on your feature
vim src/auth.js

# Stage specific files
git add src/auth.js src/auth.test.js

# Interactive commit
ai-commit

# Output:
# feat(auth): add two-factor authentication support
#
# Implement TOTP-based 2FA with QR code generation.
# Users can now enable 2FA in account settings.
#
# Commit with this message? [y/N] y
# ✅ Committed successfully!
```

---

### Example 2: Bug Fix

```bash
# Fix a bug
vim src/payment.js

# Stage the fix
git add src/payment.js

# Generate message without committing
smart-commit

# Output:
# fix(payment): prevent duplicate charge processing
#
# Add idempotency check to prevent race condition when
# users click submit multiple times rapidly.

# Looks good, commit it
git commit -m "$(smart-commit)"
```

---

### Example 3: Multiple Commits from WIP

```bash
# You have multiple changes staged
git add .

# See what AI suggests
smart-commit

# Output suggests combining too many changes
# Break it up:

git reset HEAD

# Stage and commit auth changes
git add src/auth.js
ai-commit  # Commits just auth

# Stage and commit payment changes
git add src/payment.js
ai-commit  # Commits just payment
```

---

## 🧠 How It Works

### The AI Pattern

The `smart_commit_message` pattern:

1. **Analyzes the diff**
   - What files changed
   - What code was added/removed
   - What tests were added

2. **Determines type**
   - `feat` - New feature
   - `fix` - Bug fix
   - `docs` - Documentation
   - `refactor` - Code restructuring
   - `perf` - Performance improvement
   - `test` - Test additions
   - `chore` - Maintenance

3. **Identifies scope**
   - Component/file/area affected
   - Examples: auth, payment, ui, api

4. **Writes message**
   - Subject: `type(scope): what was done`
   - Body: WHY it was done (not what)
   - Under 50 chars for subject
   - Imperative mood ("add" not "added")

---

## 💡 Pro Tips

### Tip 1: Stage Logically Related Changes

**Bad**:
```bash
git add .  # 10 unrelated files
ai-commit  # Gets confused, generic message
```

**Good**:
```bash
git add src/auth.js src/auth.test.js
ai-commit  # Clear message about auth changes

git add src/payment.js
ai-commit  # Clear message about payment changes
```

---

### Tip 2: Review Before Accepting

Always read the generated message. AI is smart but not perfect:

- Check the type (feat vs fix vs refactor)
- Verify the scope matches
- Ensure the WHY is accurate

If wrong, just say `N` and write manually.

---

### Tip 3: Use for Consistent Style

Even if you tweak the message, AI gives you:
- Correct conventional commit format
- Proper type selection
- Good scope identification
- Professional tone

Copy the structure, adjust the details.

---

### Tip 4: Combine with Git Aliases

```bash
# Quick workflow
git add .
ai-commit

# Or with your existing aliases
ga .      # Your alias for 'git add .'
ai-commit
```

---

## 🔧 Customization

### Edit the Pattern

If you want different commit style:

```bash
# Edit the pattern
vim ~/.config/fabric/patterns/smart_commit_message/system.md

# Change the format, tone, or rules
# Restart your terminal to reload
```

### Create Project-Specific Patterns

```bash
# Create pattern for this project only
mkdir -p .fabric/patterns/my_commit_style
cp ~/.config/fabric/patterns/smart_commit_message/system.md \
   .fabric/patterns/my_commit_style/system.md

# Edit for project conventions
vim .fabric/patterns/my_commit_style/system.md

# Use it
git diff --cached | fabric --pattern my_commit_style
```

---

## 🐛 Troubleshooting

### "No staged changes to commit"

**Problem**: You forgot to stage files

**Fix**:
```bash
git add <files>
ai-commit
```

---

### "fabric not found in PATH"

**Problem**: Fabric not installed or not in PATH

**Fix**:
```bash
# Check installation
which fabric

# If not found, Fabric is lazy-loaded
# Just run 'fabric' once to initialize
fabric --help

# Then try again
ai-commit
```

---

### "Error: Not in a git repository"

**Problem**: Not in a git repo

**Fix**:
```bash
# Navigate to your project
cd ~/Projects/my-project

# Then try again
ai-commit
```

---

### Generated Message is Generic

**Problem**: Too many unrelated changes staged

**Fix**: Stage related changes separately
```bash
# Instead of
git add .

# Do this
git add src/auth.js
ai-commit

git add src/payment.js
ai-commit
```

---

## 📚 Other Fabric Helpers

You also have these available:

### `doc-code <file>` - Document Code

```bash
# Generate documentation for a script
doc-code bin/update-system

# Output: README-style documentation
```

### `get-todos <file>` - Extract Action Items

```bash
# Extract TODOs from meeting notes
get-todos meeting-notes.txt

# Or from stdin
cat notes.txt | get-todos

# Output: Prioritized checklist
```

### `list-custom-patterns` - See All Patterns

```bash
# Show all available custom patterns
list-custom-patterns
```

---

## 🎓 Learning Resources

### Conventional Commits

Learn the format: https://www.conventionalcommits.org/

**Format**:
```
type(scope): description

[optional body]

[optional footer]
```

**Types**:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting
- `refactor` - Code restructuring
- `perf` - Performance
- `test` - Tests
- `chore` - Maintenance

---

## ✅ Quick Reference Card

```bash
# Full interactive commit (most common)
ai-commit

# Just generate message
smart-commit

# Manual control
git diff --cached | fabric --pattern smart_commit_message

# Document code
doc-code script.sh

# Extract TODOs
get-todos notes.txt

# List patterns
list-custom-patterns
```

---

## 🚀 Next Steps

1. **Try it now**:
   ```bash
   # Make a change
   echo "# Test" >> README.md

   # Stage it
   git add README.md

   # Try ai-commit
   ai-commit
   ```

2. **Use it daily** - Build muscle memory

3. **Adjust pattern** if you want different style

4. **Share with team** - Consistent commit messages

---

**Enjoy AI-powered commits!** 🎉

---

*Last Updated: 2025-10-31*
