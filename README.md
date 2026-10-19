# dotfiles

My config for Windows · macOS · Linux, managed by [chezmoi](https://www.chezmoi.io).

## Install

**0. Prerequisites:** [git](https://git-scm.com/downloads); on Windows also [PowerShell 7](https://aka.ms/powershell).

**1. Official installers** (by hand, before step 2):

| | Windows | macOS / Linux |
|---|---|---|
| [Cursor](https://cursor.com/downloads) | installer | installer |
| [Claude Code](https://code.claude.com/docs/en/setup) | `irm https://claude.ai/install.ps1 \| iex` | `curl -fsSL https://claude.ai/install.sh \| bash` |
| [Codex](https://github.com/openai/codex) | `irm https://chatgpt.com/codex/install.ps1 \| iex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` |
| [uv](https://docs.astral.sh/uv/) | `irm https://astral.sh/uv/install.ps1 \| iex` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

**2. Dotfiles.** Clone outside OneDrive/iCloud; synced cloud files break chezmoi.

```powershell
# Windows, in PowerShell 7 (pwsh)
git clone https://github.com/qqgjyx/dotfiles $HOME\dev\dotfiles; cd $HOME\dev\dotfiles
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser   # scoop needs it; no-op on Win 11
irm get.scoop.sh | iex; scoop install chezmoi
chezmoi init --source .; chezmoi diff; chezmoi apply
```
```sh
# macOS / Linux (Homebrew: https://brew.sh)
git clone https://github.com/qqgjyx/dotfiles ~/dev/dotfiles && cd ~/dev/dotfiles
brew install chezmoi
chezmoi init --source . && chezmoi diff && chezmoi apply
```

`init` asks for your git name, email and packages (all ticked; re-ask with `chezmoi init --prompt`).
`apply` installs the packages, writes the configs and, on Windows, enables ssh-agent + `sudo` (one UAC prompt).

## What's managed

| | |
|---|---|
| Packages ([list](src/.chezmoidata/packages.toml)) | starship, zoxide, eza, gh, JetBrains Mono NF, LaTeX (MiKTeX + Perl; MacTeX on Mac): scoop on Windows, brew elsewhere |
| Shell | pwsh profile (Windows), `.zshrc` (macOS/Linux), starship prompt |
| Git | `.gitconfig`, `.gitignore_global` |
| Editors / AI | Cursor settings + extensions, Claude Code `settings.json` |

`src/` mirrors `~` (e.g. `src/dot_gitconfig.tmpl` → `~/.gitconfig`).

## Day to day

```
chezmoi diff / apply      # preview / apply config changes   (aliases: czd / cza)
scoop update * / brew upgrade
git pull && chezmoi apply # sync another machine
```
