# ~/.config/powershell/profile.ps1 — PowerShell 7 daily-driver profile.
# Loaded by a stub at $PROFILE (see .chezmoiscripts/run_onchange_after_pwsh-profile.ps1.tmpl).
# vim:ft=ps1

# --- PSReadLine (autosuggest + syntax HL + history search) -------------------
# PredictionSource = History (not HistoryAndPlugin): plugin source probes
# PSFzf at startup, which costs ~180ms and we don't load PSFzf anymore.
# PSReadLine ships with PowerShell 7 and auto-loads, so the availability probe
# (Get-Module -ListAvailable, ~49ms) is dead weight; import it directly.
Import-Module PSReadLine
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineKeyHandler -Key Tab          -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow      -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow    -Function HistorySearchForward

# --- Tool init (cached) -----------------------------------------------------
# `& <tool> init powershell` spawns a subprocess on every shell start.
# Cache the rendered init script to disk; refresh only when the binary's
# mtime is newer than the cache. Saves ~150ms per shell.
function _UseCachedInit {
    param([string]$Tool, [string[]]$InitArgs, [string]$CacheDir)
    $bin = Get-Command $Tool -ErrorAction SilentlyContinue
    if (-not $bin) { return }
    $cache = Join-Path $CacheDir "$Tool.ps1"
    $stale = (-not (Test-Path $cache)) -or `
             ((Get-Item $bin.Source).LastWriteTimeUtc -gt (Get-Item $cache).LastWriteTimeUtc)
    if ($stale) {
        & $Tool @InitArgs | Set-Content -Path $cache -Encoding UTF8NoBOM
        # starship's full init spawns `starship prompt --continuation` on *every*
        # shell start (~67ms) just to set the PSReadLine continuation prompt.
        # Capture it once here (only on rebuild) and inline a static value. If a
        # future starship changes the init format the regex won't match and the
        # original (slower) block is left intact; no breakage, just no speedup.
        if ($Tool -eq 'starship') {
            $cont = & $Tool prompt --continuation
            $repl = "Set-PSReadLineOption -ContinuationPrompt '" + ($cont -replace "'", "''") + "'"
            $patt = '(?s)Set-PSReadLineOption -ContinuationPrompt \(\s*Invoke-Native.*?--continuation"\s*\)\s*\)'
            $text = [regex]::Replace((Get-Content $cache -Raw), $patt, { param($m) $repl })
            Set-Content -Path $cache -Value $text -Encoding UTF8NoBOM
        }
    }
    . $cache
}

$_initCacheDir = Join-Path $HOME '.cache\powershell-init'
if (-not (Test-Path $_initCacheDir)) {
    New-Item -ItemType Directory -Force -Path $_initCacheDir | Out-Null
}

# starship's plain `init powershell` returns a one-line stub that calls
# `--print-full-init` at runtime. Cache the full init so we save *both* hops.
_UseCachedInit -Tool 'starship' -InitArgs @('init','powershell','--print-full-init')      -CacheDir $_initCacheDir
_UseCachedInit -Tool 'zoxide'   -InitArgs @('init','powershell','--cmd','z')              -CacheDir $_initCacheDir

# --- Aliases -----------------------------------------------------------------
# eza — `ll` is the all-purpose long lister (always includes hidden); `la`
# aliases to it for muscle memory. `lt` is a tree view with .gitignore applied
# so node_modules / .venv / target / etc. don't drown the output.
# Flags worth keeping: --smart-group hides the redundant Admin Admin column on
# Windows; --color-scale=all gradient-colors size+age columns; --hyperlink lets
# Windows Terminal Ctrl+click filenames to open them; --total-size shows
# recursive directory sizes (slow on huge trees like node_modules — bypass
# with `eza --long ...` if it ever bites).
# Defined unconditionally (no ~17ms Get-Command probe); if eza is uninstalled
# these error at call time.
function ll { eza --icons --git --long --all --group-directories-first --smart-group --total-size --color-scale=all --hyperlink @args }
Set-Alias -Name la -Value ll
function lt { eza --icons --tree --level=2 --git-ignore @args }
# chezmoi (cz*, so nothing shadows cmd.exe)
function cza { chezmoi apply @args }
function czd { chezmoi diff @args }
function cze { chezmoi edit @args }
# git short
# PowerShell ships built-in aliases (e.g. gp -> Get-ItemProperty) that resolve
# before user-defined functions. Drop the conflicts before defining ours.
foreach ($_n in @('gp')) {
    if (Get-Alias $_n -ErrorAction SilentlyContinue) {
        Remove-Item -Path "Alias:$_n" -Force -ErrorAction SilentlyContinue
    }
}
function gs { git status --short --branch }
function gp { git pull --ff-only }

# --- Local overrides ---------------------------------------------------------
$localProfile = Join-Path $HOME ".powershell_profile.local.ps1"
if (Test-Path $localProfile) { . $localProfile }
