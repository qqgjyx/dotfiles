# bootstrap/dev-defender-exclusions.ps1 — opt-in perf optimization
#
# Adds Windows Defender exclusions for paths the dev shell touches on every
# startup (scoop apps, cached init scripts, PowerShell modules, the user
# profile dir). Cuts AV scanning of script loads — typically 100-300ms off
# cold pwsh start.
#
# REQUIRES ADMIN. Run interactively:
#   Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-File',(Resolve-Path .\bootstrap\dev-defender-exclusions.ps1).Path
#
# Tradeoff: AV no longer scans these paths. Standard dev box tradeoff —
# paths are user-writable, malicious code installed via scoop/PSGallery
# would still be caught when first downloaded by the AV engine, but later
# script loads from the cache won't be re-scanned. Skip if you can't accept
# this. Reversal: see the bottom of this file.

#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$paths = @(
    "$HOME\scoop"                                    # all scoop apps + caches
    "$HOME\.cache\powershell-init"                   # cached starship/zoxide/atuin init
    "$HOME\Documents\PowerShell"                     # the profile + Modules dir under it
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"  # PS7 stub
)

Write-Host "Adding Windows Defender exclusions for dev paths:" -ForegroundColor Cyan
foreach ($p in $paths) {
    if (Test-Path $p) {
        try {
            Add-MpPreference -ExclusionPath $p
            Write-Host "  + $p"
        } catch {
            Write-Warning "  failed: $p ($_)"
        }
    } else {
        Write-Host "  (skipped, missing) $p" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Done. Verify with:" -ForegroundColor Cyan
Write-Host "  (Get-MpPreference).ExclusionPath"
Write-Host ""
Write-Host "To reverse (run elevated):" -ForegroundColor Cyan
Write-Host "  Remove-MpPreference -ExclusionPath '<path>'"
