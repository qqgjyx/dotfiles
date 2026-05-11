# Per-machine overrides, sourced last so they win.
$localProfile = Join-Path $HOME '.powershell_profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
