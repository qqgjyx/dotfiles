# shellcheck shell=bash
# ~/.zsh/aliases.sh — sourced from both .zshrc and .bashrc.
# Curated ~15 aliases. Modern CLI replacements gate on presence.

# --- ls / eza ----------------------------------------------------------------
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --git --long --group-directories-first'
    alias la='eza --icons --git --long --all --group-directories-first'
    alias lt='eza --icons --tree --level=2'
else
    alias ll='ls -lh'
    alias la='ls -lhA'
fi

# --- cat / bat ---------------------------------------------------------------
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat'
fi

# --- fd footgun on Debian ----------------------------------------------------
command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && alias fd='fdfind'

# --- git shortcuts (lightweight; heavier ones live in gitconfig aliases) -----
alias g='git'
alias gs='git status --short --branch'
alias gp='git pull --ff-only'

# --- chezmoi -----------------------------------------------------------------
alias cma='chezmoi apply'
alias cmd='chezmoi diff'
alias cme='chezmoi edit'

# --- misc --------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias mkdir='mkdir -p'
