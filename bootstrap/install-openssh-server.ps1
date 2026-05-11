# bootstrap/install-openssh-server.ps1 — opt-in, admin-only
#
# Tailscale SSH server is not supported on Windows (literal error from
# `tailscale set --ssh=true`: "The Tailscale SSH server is not supported on
# windows"). To accept SSH inbound from your tailnet on this box, install
# the built-in Windows OpenSSH Server. Tailscale's tunnel still routes the
# traffic over the 100.x.y.z address; sshd answers it.
#
# REQUIRES ADMIN. Run interactively:
#   Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-File',(Resolve-Path .\bootstrap\install-openssh-server.ps1).Path
#
# What it does:
#   1. Add-WindowsCapability OpenSSH.Server
#   2. Start sshd + set StartupType=Automatic
#   3. Verify (or create) the inbound firewall rule on TCP 22
#   4. Set HKLM:\SOFTWARE\OpenSSH DefaultShell -> pwsh (so SSH lands in PS7,
#      not cmd.exe)
#   5. Clear Tailscale's RunSSH preference (Windows-side no-op anyway)
#   6. Print pubkey-paste instructions for administrators_authorized_keys
#
# Reversal: see notes at the bottom.

#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# 1. OpenSSH Server capability ------------------------------------------------
# Use dism.exe instead of Get-WindowsCapability / Add-WindowsCapability:
# those cmdlets rely on COM classes that aren't always registered for the
# pwsh 7 host on Windows 11 Home variants (fails with "Class not registered"
# / "没有注册类"). dism.exe is the underlying tool and works in any shell.
$dismProbe = & dism.exe /Online /Get-CapabilityInfo `
    /CapabilityName:OpenSSH.Server~~~~0.0.1.0 2>&1
$installed = ($dismProbe -join "`n") -match "State\s*:\s*Installed"
if (-not $installed) {
    Write-Host "==> dism /Online /Add-Capability OpenSSH.Server"
    & dism.exe /Online /Add-Capability `
        /CapabilityName:OpenSSH.Server~~~~0.0.1.0 /NoRestart
    if ($LASTEXITCODE -ne 0) {
        throw "dism /Add-Capability failed (exit $LASTEXITCODE)"
    }
} else {
    Write-Host "+ OpenSSH.Server already installed"
}

# 2. sshd service -------------------------------------------------------------
Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') {
    Start-Service sshd
}
Write-Host "+ sshd: $((Get-Service sshd).Status), startup $((Get-Service sshd).StartType)"

# 3. Firewall rule (the capability install adds one, but be defensive) -------
$rule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow `
        -LocalPort 22 | Out-Null
    Write-Host "+ Firewall rule created (inbound TCP 22)"
} elseif (-not $rule.Enabled) {
    Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
    Write-Host "+ Firewall rule enabled (inbound TCP 22)"
} else {
    Write-Host "+ Firewall rule already enabled (inbound TCP 22)"
}

# 4. Default shell -> pwsh ----------------------------------------------------
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if ($pwshPath) {
    if (-not (Test-Path "HKLM:\SOFTWARE\OpenSSH")) {
        New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
    }
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" `
        -Value $pwshPath -PropertyType String -Force | Out-Null
    Write-Host "+ DefaultShell -> $pwshPath"
} else {
    Write-Warning "pwsh not on PATH; default shell stays as cmd.exe. Install pwsh and re-run to set."
}

# 5. Drop Tailscale's RunSSH no-op (it errors on Windows anyway) -------------
$tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
if ($tailscale) {
    & $tailscale.Source set --ssh=false 2>$null | Out-Null
    Write-Host "+ Tailscale RunSSH cleared (no-op on Windows)"
}

# 6. Next steps ---------------------------------------------------------------
$keyFile = "C:\ProgramData\ssh\administrators_authorized_keys"
Write-Host ""
Write-Host "OpenSSH Server is up." -ForegroundColor Cyan
Write-Host ""
Write-Host "Wire up key auth:" -ForegroundColor Cyan
Write-Host "  1. On the client (e.g. macOS, Linux), copy the public key:"
Write-Host "       cat ~/.ssh/id_ed25519.pub"
Write-Host "       (no key? generate: ssh-keygen -t ed25519 -C ""you@host"")"
Write-Host "  2. On THIS box, paste that one line into:"
Write-Host "       $keyFile"
Write-Host "     (Admin users on Windows OpenSSH use this system file, not"
Write-Host "      ~/.ssh/authorized_keys. Non-admin users use the per-user file.)"
Write-Host "  3. Lock down the file's ACL:"
Write-Host "       icacls $keyFile /inheritance:r"
Write-Host "       icacls $keyFile /grant Administrators:F SYSTEM:F"
Write-Host "  4. Test: from the client, ssh <this-box-name>"
Write-Host ""
Write-Host "Reversal:" -ForegroundColor Cyan
Write-Host "  Stop-Service sshd; Set-Service sshd -StartupType Disabled"
Write-Host "  Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"
Write-Host "  Remove-NetFirewallRule -Name OpenSSH-Server-In-TCP"
Write-Host "  Remove-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell"
