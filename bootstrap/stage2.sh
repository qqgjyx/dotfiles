#!/usr/bin/env bash
# bootstrap/stage2.sh — v2 dotfiles, post-`gh auth login`
#
# Clones the two private companion repos, then runs `chezmoi init --apply`
# against the existing ~/dotfiles checkout. Optionally generates an ed25519
# SSH key if one isn't present.
#
# Prerequisites:
#   - stage1.sh completed (chezmoi, gh available)
#   - gh auth login completed (run between stage1 and stage2)

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
log()  { printf '==> %s\n' "$*"; }

# Pre-flight
for tool in gh chezmoi git; do
    have "$tool" || { echo "$tool not found. Run bootstrap/stage1.sh first." >&2; exit 1; }
done

gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated. Run 'gh auth login' first." >&2; exit 1; }

# 1. Clone private companion repos
SKILLS_DIR="$HOME/.claude/skills"
SSHCFG_DIR="$HOME/.ssh-config-private"

if [ ! -d "$SKILLS_DIR" ]; then
    log "Cloning qqgjyx/skills to $SKILLS_DIR"
    mkdir -p "$(dirname "$SKILLS_DIR")"
    gh repo clone qqgjyx/skills "$SKILLS_DIR"
else
    echo "✓ skills already cloned at $SKILLS_DIR"
fi

if [ ! -d "$SSHCFG_DIR" ]; then
    log "Cloning qqgjyx/_ssh-config to $SSHCFG_DIR"
    gh repo clone qqgjyx/_ssh-config "$SSHCFG_DIR"
    echo "  (review $SSHCFG_DIR/README for ~/.ssh/config wiring)"
else
    echo "✓ ssh-config already cloned at $SSHCFG_DIR"
fi

# 2. SSH key generation (interactive)
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    read -r -p "Generate a new ed25519 SSH key now? [y/N] " reply
    if [[ "$reply" =~ ^[Yy] ]]; then
        mkdir -p "$(dirname "$SSH_KEY")"
        chmod 700 "$(dirname "$SSH_KEY")"
        ssh-keygen -t ed25519 -C "150919274+qqgjyx@users.noreply.github.com" -f "$SSH_KEY"
        echo "Public key:"
        cat "$SSH_KEY.pub"
        echo "Add it to GitHub: gh ssh-key add $SSH_KEY.pub --title \"$(hostname)\""
    fi
else
    echo "✓ SSH key exists at $SSH_KEY"
fi

# 3. chezmoi apply against the existing ~/dotfiles source
SOURCE="$HOME/dotfiles"
if [ ! -f "$SOURCE/.chezmoiroot" ]; then
    echo "$SOURCE doesn't look like a chezmoi source (no .chezmoiroot found)." >&2
    exit 1
fi

log "chezmoi init --apply --source \"$SOURCE\""
chezmoi init --apply --source "$SOURCE"

cat <<'EOF'

================================================================
Stage 2 complete.

Verify:
  chezmoi diff     # should be empty
  chezmoi verify   # should exit 0
================================================================
EOF
