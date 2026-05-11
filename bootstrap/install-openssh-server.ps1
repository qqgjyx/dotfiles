# bootstrap/install-openssh-server.ps1 — opt-in, admin-only
#
# Tailscale SSH server is not supported on Windows ("The Tailscale SSH
# server is not supported on windows" — literal error from
# `tailscale set --ssh=true`). To accept SSH inbound from your tailnet on
# this box, install Windows OpenSSH. Tailscale's tunnel still routes the
# 100.x.y.z traffic; sshd answers it.
#
# Path: scoop install openssh (NOT Add-WindowsCapability).
#   Add-WindowsCapability OpenSSH.Server is unreliable on Windows 11 Home
#   China editions: DISM/CBS errors with HRESULT 0x80070002 ("file not
#   found") trying to fetch the FoD package from Microsoft Update. The
#   scoop manifest pulls the identical Win32-OpenSSH binaries from the
#   official Microsoft GitHub release — same upstream codebase, no FoD
#   dependency.
#
# REQUIRES ADMIN. Run interactively:
#   Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-File',(Resolve-Path .\bootstrap\install-openssh-server.ps1).Path
#
# What it does:
#   1. scoop install openssh (idempotent — skips if present)
#   2. install-sshd.ps1 to register sshd + ssh-agent services
#   3. Drop the IFEO RedirectionGuard sshd.exe key (install-sshd.ps1 adds
#      it; it kills the process when launched via scoop's symlinked path
#      — exit status 0xc00004bc / STATUS_REDIRECTION_GUARD_VIOLATION)
#   4. Copy sshd_config_default -> C:\ProgramData\ssh\sshd_config if missing
#   5. ssh-keygen -A to generate host keys
#   6. FixHostFilePermissions.ps1 to set the right ACLs
#   7. Start sshd + auto-start
#   8. Verify (or create) inbound TCP 22 firewall rule
#   9. HKLM:\SOFTWARE\OpenSSH DefaultShell -> pwsh
#  10. Clear Tailscale RunSSH preference (Windows-side no-op anyway)
#  11. Print client-side instructions for administrators_authorized_keys

#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Make scoop reachable from elevated shell (User PATH may not be inherited)
if (Test-Path "$env:USERPROFILE\scoop\shims") {
    $env:Path = "$env:USERPROFILE\scoop\shims;$env:Path"
}
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw "scoop not found. Run bootstrap/stage1.ps1 first."
}

# 1. Install Win32-OpenSSH via scoop -----------------------------------------
$opensshDir = "$env:USERPROFILE\scoop\apps\openssh\current"
if (-not (Test-Path "$opensshDir\sshd.exe")) {
    Write-Host "==> scoop install openssh"
    scoop install openssh
    if ($LASTEXITCODE -ne 0) { throw "scoop install openssh failed (exit $LASTEXITCODE)" }
} else {
    Write-Host "+ Win32-OpenSSH already installed at $opensshDir"
}

# 2. Register services -------------------------------------------------------
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
    Write-Host "==> install-sshd.ps1"
    & "$opensshDir\install-sshd.ps1"
} else {
    Write-Host "+ sshd service already registered"
}

# 3. Drop IFEO RedirectionGuard ----------------------------------------------
# install-sshd.ps1 sets a process mitigation on sshd.exe that crashes the
# process when launched through scoop's symlink (~/scoop/apps/openssh/current
# -> ~/scoop/apps/openssh/<version>). Status code 0xc00004bc =
# STATUS_REDIRECTION_GUARD_VIOLATION. Drop the IFEO key; sshd starts cleanly.
$ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sshd.exe'
if (Test-Path $ifeo) {
    Remove-Item $ifeo -Recurse -Force
    Write-Host "+ removed IFEO RedirectionGuard key (incompatible with scoop's symlinked layout)"
}

# 4. sshd_config + host keys + ACLs ------------------------------------------
$cfgDir = 'C:\ProgramData\ssh'
if (-not (Test-Path $cfgDir)) {
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
}
if (-not (Test-Path "$cfgDir\sshd_config")) {
    Copy-Item "$opensshDir\sshd_config_default" "$cfgDir\sshd_config"
    Write-Host "+ sshd_config copied from $opensshDir\sshd_config_default"
}
# -A generates only the missing host key types; no-op if all present
& "$opensshDir\ssh-keygen.exe" -A | Out-Null
Write-Host "+ host keys present"
# Repairs ACLs on host keys + config + ProgramData\ssh
& "$opensshDir\FixHostFilePermissions.ps1" -Confirm:$false | Out-Null
Write-Host "+ host file permissions repaired"

# 5. Service start + auto-start ----------------------------------------------
Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') {
    Start-Service sshd
}
$svc = Get-Service sshd
Write-Host "+ sshd: $($svc.Status), startup $($svc.StartType)"

# 6. Firewall rule -----------------------------------------------------------
$rule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow `
        -LocalPort 22 | Out-Null
    Write-Host "+ Firewall rule created (inbound TCP 22)"
} elseif (-not $rule.Enabled) {
    Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
    Write-Host "+ Firewall rule enabled"
} else {
    Write-Host "+ Firewall rule already enabled"
}

# 7. Default shell -> pwsh ---------------------------------------------------
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if ($pwshPath) {
    if (-not (Test-Path "HKLM:\SOFTWARE\OpenSSH")) {
        New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
    }
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" `
        -Value $pwshPath -PropertyType String -Force | Out-Null
    Write-Host "+ DefaultShell -> $pwshPath"
} else {
    Write-Warning "pwsh not on PATH; default shell stays as cmd.exe."
}

# 8. Drop Tailscale's RunSSH no-op -------------------------------------------
$tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
if (-not $tailscale) {
    foreach ($p in @("$env:ProgramFiles\Tailscale\tailscale.exe", "D:\Tailscale\tailscale.exe")) {
        if (Test-Path $p) { $tailscale = Get-Item $p; break }
    }
}
if ($tailscale) {
    & $tailscale.Source set --ssh=false 2>$null | Out-Null
    Write-Host "+ Tailscale RunSSH cleared (no-op on Windows)"
}

# 9. Next steps --------------------------------------------------------------
$keyFile = "$cfgDir\administrators_authorized_keys"
$winUser = $env:USERNAME
Write-Host ""
Write-Host "OpenSSH Server is up and listening on TCP 22." -ForegroundColor Cyan
Write-Host ""
Write-Host "Wire up key auth:" -ForegroundColor Cyan
Write-Host "  1. On the client (e.g. macOS, Linux), copy your public key:"
Write-Host "       cat ~/.ssh/id_ed25519.pub"
Write-Host "     (no key? generate: ssh-keygen -t ed25519 -C `"you@host`")"
Write-Host "  2. On THIS box, append that single line to:"
Write-Host "       $keyFile"
Write-Host "     (Admin users on Windows OpenSSH use this system file, not"
Write-Host "      the per-user ~/.ssh/authorized_keys.)"
Write-Host "  3. Lock down the ACL (after the file exists):"
Write-Host "       icacls `"$keyFile`" /inheritance:r"
Write-Host "       icacls `"$keyFile`" /grant Administrators:F SYSTEM:F"
Write-Host "  4. Test from the client:"
Write-Host "       ssh $winUser@<box-name>      # username on this box is `"$winUser`""
Write-Host "       ssh $winUser@<tailnet-ip>    # if MagicDNS isn't routing"
Write-Host "  5. (Optional) On the client, add to ~/.ssh/config so the user sticks:"
Write-Host "       Host <box-name>"
Write-Host "         User $winUser"
Write-Host "         IdentityFile ~/.ssh/id_ed25519"
Write-Host ""
Write-Host "Reversal:" -ForegroundColor Cyan
Write-Host "  Stop-Service sshd"
Write-Host "  & `"$opensshDir\uninstall-sshd.ps1`""
Write-Host "  Remove-NetFirewallRule -Name OpenSSH-Server-In-TCP"
Write-Host "  Remove-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell"
Write-Host "  scoop uninstall openssh"
