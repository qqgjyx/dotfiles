# Idempotent symlink installer for Windows.
# Run from an elevated PowerShell:  .\bootstrap.ps1
#
# Requires Administrator (or Developer Mode) so SymbolicLink creation is allowed.
# Backs up existing real files to *.dotfiles-bak.<timestamp> before linking.

$ErrorActionPreference = 'Stop'

$dotfiles = Split-Path -Parent $MyInvocation.MyCommand.Path
$homeSrc  = Join-Path $dotfiles 'home'
$winSrc   = Join-Path $dotfiles 'win'

function Link-File {
    param([string]$Source, [string]$Target)

    $targetDir = Split-Path -Parent $Target
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Remove-Item $Target -Force
        } else {
            $stamp = Get-Date -Format 'yyyyMMddHHmmss'
            Move-Item $Target "$Target.dotfiles-bak.$stamp"
        }
    }

    New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
    Write-Host "linked  $Target -> $Source"
}

# 1) Everything in home/ -> $HOME\<name>
Get-ChildItem -Force -File $homeSrc | ForEach-Object {
    Link-File -Source $_.FullName -Target (Join-Path $HOME $_.Name)
}

# 2) PowerShell profile (lives in Documents\PowerShell on PS 7+, Documents\WindowsPowerShell on 5.1)
$psProfileSrc = Join-Path $winSrc 'Microsoft.PowerShell_profile.ps1'
if (Test-Path $psProfileSrc) {
    foreach ($psHost in @('PowerShell', 'WindowsPowerShell')) {
        $target = Join-Path $HOME "Documents\$psHost\Microsoft.PowerShell_profile.ps1"
        Link-File -Source $psProfileSrc -Target $target
    }
}

Write-Host "`ndone."
