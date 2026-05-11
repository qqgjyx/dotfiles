# bootstrap/stage1.ps1 — v2 dotfiles, Windows first-touch
#
# Installs scoop (primary) + the core CLI stack + chezmoi + gh.
# Idempotent: safe to re-run.
# Next step after this completes: `gh auth login`, then `bootstrap/stage2.ps1`.
#
# Run from an elevated or non-elevated PowerShell — scoop installs to $HOME\scoop,
# no admin needed. Elevation is only required if execution policy is restricted.

#Requires -Version 5.1

# Note: do NOT set $ErrorActionPreference = "Stop". In PowerShell 5.1, that
# wraps every native-command stderr line in a terminating ErrorRecord, so
# benign output (e.g. scoop's progress writes) aborts the script.
# Check $LASTEXITCODE explicitly where it matters instead.
$ErrorActionPreference = "Continue"

function Test-Cmd { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

Write-Host "==> stage1: Windows bootstrap"

# 1. ExecutionPolicy — RemoteSigned for CurrentUser (won't override stricter Machine policy)
if ((Get-ExecutionPolicy -Scope CurrentUser) -in @("Restricted", "Undefined")) {
    Write-Host "Setting ExecutionPolicy CurrentUser=RemoteSigned"
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

# 2. Scoop — primary package manager
if (-not (Test-Cmd "scoop")) {
    Write-Host "==> Installing scoop"
    Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
} else {
    Write-Host "scoop already installed"
}

# 3. Buckets — main is default; extras for less-common tools
scoop bucket add main 2>$null | Out-Null
scoop bucket add extras 2>$null | Out-Null

# 4. Core packages — package manager + chezmoi + gh + shell stack + CLI utilities
$packages = @(
    "git",        # required for chezmoi
    "pwsh",       # PowerShell 7 — the actual daily shell
    "chezmoi",    # the manager itself
    "gh",         # GitHub CLI (used by stage2 to clone private repos)
    "starship",   # prompt
    "eza",        # ls replacement
    "bat",        # cat replacement
    "fd",         # find replacement
    "ripgrep",    # grep replacement
    "fzf",        # fuzzy finder
    "zoxide",     # smarter cd
    "delta",      # git diff pager
    "atuin"       # shell history
)

foreach ($p in $packages) {
    if (Test-Cmd $p) {
        Write-Host "✓ $p"
    } else {
        Write-Host "==> scoop install $p"
        scoop install $p
    }
}

Write-Host ""
Write-Host "================================================================"
Write-Host "Stage 1 complete."
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. gh auth login          # authenticate to GitHub (interactive)"
Write-Host "  2. .\bootstrap\stage2.ps1 # clone privates + chezmoi apply"
Write-Host "================================================================"
