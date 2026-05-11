# bootstrap/stage2.ps1 — v2 dotfiles, post-`gh auth login`
#
# Clones the two private companion repos, then runs `chezmoi init --apply`
# against the existing ~/dotfiles checkout. Optionally generates an ed25519
# SSH key if one isn't present.
#
# Prerequisites:
#   - stage1.ps1 completed (chezmoi, gh, pwsh available)
#   - gh auth login completed (run between stage1 and stage2)

#Requires -Version 5.1

# Note: do NOT set $ErrorActionPreference = "Stop". In PowerShell 5.1, that
# wraps every native-command stderr line in a terminating ErrorRecord, so
# benign output like `gh repo clone`'s "Cloning into..." aborts the script.
# Check $LASTEXITCODE explicitly where it matters instead.
$ErrorActionPreference = "Continue"

function Test-Cmd { param([string]$Name) [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Assert-Exit {
    param([string]$What)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$What failed (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
}

# Pre-flight
foreach ($tool in @("gh", "chezmoi", "git")) {
    if (-not (Test-Cmd $tool)) {
        Write-Error "$tool not found. Run bootstrap/stage1.ps1 first."
        exit 1
    }
}

$gh_status = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "gh is not authenticated. Run 'gh auth login' first."
    exit 1
}

# 1. Clone private companion repos
$skills_dir = Join-Path $HOME ".claude\skills"
$sshcfg_dir = Join-Path $HOME ".ssh-config-private"

if (-not (Test-Path $skills_dir)) {
    Write-Host "==> Cloning qqgjyx/skills to $skills_dir"
    New-Item -ItemType Directory -Force -Path (Split-Path $skills_dir) | Out-Null
    gh repo clone qqgjyx/skills $skills_dir
    Assert-Exit "gh repo clone qqgjyx/skills"
} else {
    Write-Host "✓ skills already cloned at $skills_dir"
}

if (-not (Test-Path $sshcfg_dir)) {
    Write-Host "==> Cloning qqgjyx/ssh-config to $sshcfg_dir"
    gh repo clone qqgjyx/ssh-config $sshcfg_dir
    Assert-Exit "gh repo clone qqgjyx/ssh-config"
    Write-Host "  (review $sshcfg_dir\README for ~/.ssh/config wiring)"
} else {
    Write-Host "✓ ssh-config already cloned at $sshcfg_dir"
}

# 2. SSH key generation (interactive)
$ssh_key = Join-Path $HOME ".ssh\id_ed25519"
if (-not (Test-Path $ssh_key)) {
    $reply = Read-Host "Generate a new ed25519 SSH key now? [y/N]"
    if ($reply -match '^[Yy]') {
        New-Item -ItemType Directory -Force -Path (Split-Path $ssh_key) | Out-Null
        ssh-keygen -t ed25519 -C "150919274+qqgjyx@users.noreply.github.com" -f $ssh_key
        Write-Host "Public key:"
        Get-Content "$ssh_key.pub"
        Write-Host "Add it to GitHub: gh ssh-key add $ssh_key.pub --title `"$env:COMPUTERNAME`""
    }
} else {
    Write-Host "✓ SSH key exists at $ssh_key"
}

# 3. chezmoi apply against the existing ~/dotfiles source
$source = Join-Path $HOME "dotfiles"
if (-not (Test-Path (Join-Path $source ".chezmoiroot"))) {
    Write-Error "$source doesn't look like a chezmoi source (no .chezmoiroot found)."
    exit 1
}

Write-Host "==> chezmoi init --apply --source `"$source`""
chezmoi init --apply --source "$source"
Assert-Exit "chezmoi init --apply"

Write-Host ""
Write-Host "================================================================"
Write-Host "Stage 2 complete."
Write-Host ""
Write-Host "Verify:"
Write-Host "  chezmoi diff     # should be empty"
Write-Host "  chezmoi verify   # should exit 0"
Write-Host "================================================================"
