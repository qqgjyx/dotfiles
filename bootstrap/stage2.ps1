# bootstrap/stage2.ps1 — v2 dotfiles, post-`gh auth login`
#
# Clones the two private companion repos, then runs `chezmoi init --apply`
# against the existing ~/dotfiles checkout. Optionally generates an ed25519
# SSH key if one isn't present.
#
# Authoring-box mode for SSH config: if you have qqgjyx/_ssh-config already
# checked out (e.g. on OneDrive-synced project storage), set
#   $env:SSH_CONFIG_REPO_DIR = "D:\OneDrive\Documents\_Projects\_ssh-config"
# before running stage2. It'll junction ~/.ssh-config-working -> that path
# instead of cloning a second copy to ~/.ssh-config-private. An already-
# existing junction at ~/.ssh-config-working is also left untouched.
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

$sshcfg_link = Join-Path $HOME ".ssh-config-working"
$existing_junction = (Test-Path $sshcfg_link) -and ((Get-Item $sshcfg_link -Force).LinkType -eq 'Junction')
$env_target = if ($env:SSH_CONFIG_REPO_DIR -and (Test-Path $env:SSH_CONFIG_REPO_DIR)) { $env:SSH_CONFIG_REPO_DIR } else { $null }
$include_hint = ($sshcfg_link -replace '\\','/')

if ($existing_junction) {
    Write-Host "✓ junction $sshcfg_link -> $((Get-Item $sshcfg_link -Force).Target) (left as-is)"
    Write-Host "  ~/.ssh/config should: Include $include_hint/config"
} elseif ($env_target) {
    Write-Host "==> SSH_CONFIG_REPO_DIR set; junctioning $sshcfg_link -> $env_target"
    cmd /c mklink /J "$sshcfg_link" "$env_target" | Out-Null
    Assert-Exit "mklink /J $sshcfg_link"
    Write-Host "  ~/.ssh/config should: Include $include_hint/config"
} elseif (-not (Test-Path $sshcfg_dir)) {
    Write-Host "==> Cloning qqgjyx/_ssh-config to $sshcfg_dir"
    gh repo clone qqgjyx/_ssh-config $sshcfg_dir
    Assert-Exit "gh repo clone qqgjyx/_ssh-config"
    Write-Host "  (review $sshcfg_dir\README for ~/.ssh/config wiring)"
} else {
    Write-Host "✓ ssh-config already cloned at $sshcfg_dir"
}

# 1b. Multiplexing override in ~/.ssh/config. Windows OpenSSH can't speak the
# Unix-socket ControlPath that some _ssh-config versions or other includes may
# set; force it off here. Defense-in-depth: as of qqgjyx/_ssh-config#15 the
# source no longer sets multiplexing, so this only matters if an older copy or
# a downstream re-add slips in. Sentinel-bracketed for idempotency.
$ssh_dir = Join-Path $HOME ".ssh"
$ssh_config = Join-Path $ssh_dir "config"
$mp_start = "# >>> qqgjyx/dotfiles managed: windows ssh multiplexing override >>>"
$mp_end   = "# <<< qqgjyx/dotfiles managed: windows ssh multiplexing override <<<"
$mp_block = @"
$mp_start
Host *
    ControlMaster no
    ControlPath none
$mp_end


"@
New-Item -ItemType Directory -Force -Path $ssh_dir | Out-Null
$existing_cfg = if (Test-Path $ssh_config) { Get-Content $ssh_config -Raw } else { "" }
if ($existing_cfg -notmatch [regex]::Escape($mp_start)) {
    Set-Content -Path $ssh_config -Value ($mp_block + $existing_cfg) -Encoding UTF8 -NoNewline
    Write-Host "+ added multiplexing override to $ssh_config"
} else {
    Write-Host "✓ multiplexing override already in $ssh_config"
}

# 1c. ACL lockdown on the junction's config file when junction is in play.
# OpenSSH refuses Include'd files where Authenticated Users has any access,
# which is OneDrive's default inherited ACL. Target the file specifically so
# editing access via OneDrive on the rest of the repo is preserved.
# Caveat: OneDrive may re-apply inherited ACLs on round-trip sync — re-run
# stage2 (idempotent) if "Bad permissions" returns.
if ($existing_junction -or $env_target) {
    $cfg_file = Join-Path $sshcfg_link "config"
    if (Test-Path $cfg_file) {
        Write-Host "==> icacls lockdown on $cfg_file"
        icacls "$cfg_file" /inheritance:r /grant:r "${env:USERNAME}:F" /grant:r "SYSTEM:F" | Out-Null
        Assert-Exit "icacls $cfg_file"
    } else {
        Write-Warning "junction in place but $cfg_file not found; skipping icacls (re-run stage2 once the included config exists)"
    }
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
