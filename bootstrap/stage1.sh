#!/usr/bin/env bash
# bootstrap/stage1.sh — v2 dotfiles, POSIX first-touch
#
# Installs distro package manager prerequisites + chezmoi + gh + starship + core CLI tools.
# Idempotent: safe to re-run.
# Next step after this completes: `gh auth login`, then `bootstrap/stage2.sh`.

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
log()  { printf '==> %s\n' "$*"; }

OS="$(uname -s)"
echo "==> stage1: POSIX bootstrap ($OS)"

install_macos() {
    if ! have brew; then
        log "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # shellcheck disable=SC2046
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    fi
    # Core packages — every profile gets these. Power-user CLI extras
    # (fd, ripgrep, fzf, git-delta, atuin) are profile-gated and install via
    # run_onchange_install-packages.sh.tmpl when profile=full.
    local pkgs=(
        zsh git curl
        chezmoi gh starship
        eza bat zoxide
    )
    for p in "${pkgs[@]}"; do
        if brew list --formula 2>/dev/null | grep -qx "$p"; then
            echo "✓ $p"
        else
            log "brew install $p"
            brew install "$p"
        fi
    done

    # JetBrains Mono Nerd Font — required by starship glyphs and the Cursor fontFamily.
    # Cask, not formula; idempotency check via `brew list --cask`.
    local font_cask="font-jetbrains-mono-nerd-font"
    if brew list --cask 2>/dev/null | grep -qx "$font_cask"; then
        echo "✓ $font_cask"
    else
        log "brew install --cask $font_cask"
        brew install --cask "$font_cask"
    fi
}

install_linux() {
    # Distro-essential prerequisites first via system package manager
    if have apt-get; then
        sudo apt-get update -qq
        sudo apt-get install -y zsh git curl ca-certificates
    elif have dnf; then
        sudo dnf install -y zsh git curl
    elif have pacman; then
        sudo pacman -Sy --noconfirm zsh git curl
        # Arch has everything we need in repos
        sudo pacman -S --noconfirm chezmoi gh starship eza bat fd ripgrep fzf zoxide git-delta atuin
        return
    else
        echo "Unsupported Linux package manager. Install chezmoi/gh manually, then re-run." >&2
        exit 1
    fi

    # chezmoi via official installer (always latest, distro-independent)
    if ! have chezmoi; then
        log "Installing chezmoi"
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # starship via official installer
    if ! have starship; then
        log "Installing starship"
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi

    # gh — use distro-specific repo
    if ! have gh; then
        if have apt-get; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
            sudo apt-get update -qq && sudo apt-get install -y gh
        elif have dnf; then
            sudo dnf install -y 'dnf-command(config-manager)'
            sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
            sudo dnf install -y gh
        fi
    fi

    # The rest — installed during `chezmoi apply` via run_onchange_install-packages.sh.tmpl.
    # We don't try to install eza/bat/fd/rg/fzf/zoxide/delta/atuin here; coverage varies
    # too much across distros and `chezmoi apply` handles it consistently.
}

case "$OS" in
    Darwin) install_macos ;;
    Linux)  install_linux ;;
    *)      echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

cat <<'EOF'

================================================================
Stage 1 complete.

Next steps:
  1. gh auth login          # authenticate to GitHub (interactive)
  2. bash bootstrap/stage2.sh   # clone privates + chezmoi apply
================================================================
EOF
