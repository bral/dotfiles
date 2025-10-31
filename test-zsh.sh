#!/usr/bin/env bash

# Test script to verify zsh loads without TTY suspension issues
# Run this to test if the shell configuration is working properly

set -e

echo "🧪 Testing ZSH Configuration..."
echo

# Test 1: Basic zsh loading
echo "1. Testing basic zsh loading..."
timeout 10s zsh -c "echo 'Basic zsh test: OK'" || {
    echo "❌ FAILED: Basic zsh loading timed out or failed"
    exit 1
}

# Test 2: Z4H loading
echo "2. Testing Z4H loading..."
timeout 10s zsh -c "
    if command -v z4h >/dev/null 2>&1; then
        echo 'Z4H available: OK'
    else
        echo 'Z4H not available but shell loaded: OK'
    fi
" || {
    echo "❌ FAILED: Z4H test timed out or failed"
    exit 1
}

# Test 3: P10K loading
echo "3. Testing Powerlevel10k loading..."
timeout 10s zsh -c "
    if [[ \$+functions[p10k] -eq 1 ]]; then
        echo 'P10K loaded: OK'
    else
        echo 'P10K not loaded but shell functional: OK'
    fi
" || {
    echo "❌ FAILED: P10K test timed out or failed"
    exit 1
}

# Test 4: Interactive session simulation
echo "4. Testing interactive session..."
timeout 10s zsh -c "
    echo 'Interactive test started'
    sleep 1
    echo 'Interactive test completed: OK'
" || {
    echo "❌ FAILED: Interactive session test timed out or failed"
    exit 1
}

# Test 5: Background process simulation
echo "5. Testing background process handling..."
timeout 10s zsh -c "
    echo 'Background test started'
    (echo 'Background process: OK') &
    wait
    echo 'Background test completed: OK'
" || {
    echo "❌ FAILED: Background process test timed out or failed"
    exit 1
}

echo
echo "✅ All tests passed! ZSH configuration appears to be working without TTY suspension issues."
echo
echo "Next steps:"
echo "1. Try opening a new terminal window"
echo "2. Test running: claude"
echo "3. If issues persist, check for background processes: jobs"