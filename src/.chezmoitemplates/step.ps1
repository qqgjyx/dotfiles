# step: print a command, run it, remember failures. finish: list them, exit 1 so
# chezmoi retries the script on the next apply.
$failed = @()
function step {
    $cmd = $args[0]; [object[]]$rest = $args | Select-Object -Skip 1
    Write-Host "==> $args"
    $global:LASTEXITCODE = 0
    & $cmd @rest
    if ($LASTEXITCODE) { $script:failed += "$args" }
}
function finish {
    if (-not $failed) { return }
    Write-Host 'failed:'; $failed | ForEach-Object { Write-Host "  $_" }
    exit 1
}
