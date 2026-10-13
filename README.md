# dotfiles

Personal config for [@qqgjyx](https://github.com/qqgjyx), managed by [chezmoi](https://www.chezmoi.io).
Windows 11 · macOS · Linux.

## Install

### 0. Prerequisites (by hand)

- **git**: [git-scm.com](https://git-scm.com/downloads) (macOS: `xcode-select --install`)
- **PowerShell 7** (Windows only): [aka.ms/powershell](https://aka.ms/powershell)

### Tier 1: apps and self-updating tools (official installers, by hand)

| Tool | Windows (PowerShell) | macOS / Linux |
|---|---|---|
| [Cursor](https://cursor.com/downloads) | download installer | download installer |
| [Claude Code](https://code.claude.com/docs/en/setup) | `irm https://claude.ai/install.ps1 \| iex` | `curl -fsSL https://claude.ai/install.sh \| bash` |
| [Codex](https://github.com/openai/codex) | `irm https://chatgpt.com/codex/install.ps1 \| iex` | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` |
| [uv](https://docs.astral.sh/uv/) | `irm https://astral.sh/uv/install.ps1 \| iex` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

Install these before Tier 2 so the Cursor extensions can be installed on the first run. They also
work if you add them later: run `chezmoi apply` again.

### Tier 2: dotfiles

Clone anywhere **outside OneDrive/iCloud**. Synced "cloud files" break chezmoi.

**Windows**
```powershell
git clone https://github.com/qqgjyx/dotfiles ~\dev\dotfiles; cd ~\dev\dotfiles
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser   # allow local scripts (no-op on most Win 11)
irm get.scoop.sh | iex                                # package manager
scoop install chezmoi
chezmoi init --source .                               # asks: name, email, packages
chezmoi diff                                          # review what will change
chezmoi apply
```

**macOS / Linux**
```sh
git clone https://github.com/qqgjyx/dotfiles ~/dev/dotfiles && cd ~/dev/dotfiles
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --source . && chezmoi diff && chezmoi apply
```

## What Tier 2 does

- **Asks once**: your git name and email, and which packages to install (all ticked by default).
  To change your answers, run `chezmoi init --prompt`.
- **Installs packages** (scoop on Windows, brew elsewhere), listed in
  [`src/.chezmoidata/packages.toml`](src/.chezmoidata/packages.toml):
  starship, zoxide, eza, gh, JetBrains Mono Nerd Font, LaTeX (MiKTeX / MacTeX).
- **Writes configs**: `~/.gitconfig`, `~/.gitignore_global`, starship, the pwsh profile (Windows) or
  `.zshrc` (macOS/Linux), Cursor settings and extensions, and Claude Code `CLAUDE.md` + `settings.json`.
- **Windows only, once**: enables the ssh-agent service and inline `sudo`. This shows one UAC prompt.

## Day to day

| | |
|---|---|
| update packages | `scoop update *` / `brew upgrade` |
| edit a config | `chezmoi edit <file>`, or edit `src/` directly, then `chezmoi apply` (`cza`) |
| preview changes | `chezmoi diff` (`czd`) |
| pull on another machine | `git pull`, then `chezmoi apply` |
| add a package | add a line to `src/.chezmoidata/packages.toml`, then `chezmoi init --prompt` |

## Layout

```
src/                                  chezmoi source root (.chezmoiroot); mirrors ~
├── .chezmoi.toml.tmpl                init questions
├── .chezmoidata/                     packages.toml (tick list), cursor.toml (extensions)
├── .chezmoiscripts/                  packages, admin (Windows), pwsh-profile stub, cursor-extensions
├── .chezmoitemplates/                cursor-settings.json (shared by the 3 per-OS paths)
├── .chezmoiignore                    per-OS skips
├── dot_gitconfig.tmpl                ~/.gitconfig
├── dot_gitignore_global              ~/.gitignore_global
├── dot_zshrc, dot_zsh_plugins.txt    zsh (macOS/Linux)
├── dot_config/powershell/profile.ps1 pwsh profile (Windows; $PROFILE gets a stub that loads it)
├── dot_config/starship.toml          prompt
├── dot_claude/                       Claude Code CLAUDE.md + settings.json
└── AppData/… Library/… dot_config/Cursor/…   Cursor settings, per OS
```

## Credits

`src/dot_claude/CLAUDE.md` is vendored from
[forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills);
see that file's header comment for attribution.

## License

MIT
