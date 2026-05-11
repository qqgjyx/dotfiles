# dotfiles

Personal cross-platform configuration for [@qqgjyx](https://github.com/qqgjyx) — managed by [chezmoi](https://www.chezmoi.io).

Targets: **Windows 11** (current daily driver) · **macOS** · **Linux**

---

## Quick start

```bash
git clone https://github.com/qqgjyx/dotfiles ~/dotfiles
cd ~/dotfiles
./bootstrap/stage1.sh        # or: .\bootstrap\stage1.ps1 on Windows
gh auth login                # interactive (between stages)
./bootstrap/stage2.sh        # or: .\bootstrap\stage2.ps1 on Windows
```

That's it. Stage 1 installs the package manager + chezmoi + core CLI; stage 2 clones the two private companion repos and runs `chezmoi apply`.

---

## Architecture

Three repos work together:

| Repo | Visibility | Purpose |
|---|---|---|
| `qqgjyx/dotfiles` *(this)* | public | chezmoi source state — non-sensitive configs |
| `qqgjyx/skills` | private | Claude Code skills → cloned to `~/.claude/skills/` |
| `qqgjyx/ssh-config` | private | `~/.ssh/config` + per-host fragments |

Why chezmoi: Go-templated source state with per-machine variables, OS-conditional ignores, and idempotent `apply`. The full design rationale is in the [v2 migration PR](https://github.com/qqgjyx/dotfiles/issues/1).

---

## Features

### Shell

| | Windows | macOS | Linux |
|---|---|---|---|
| Runtime | PowerShell 7 | zsh | zsh |
| Plugin mgr | PSGallery (built-in) | antidote | antidote |
| Autosuggest | PSReadLine InlineView | zsh-autosuggestions | zsh-autosuggestions |
| Syntax HL | PSReadLine | zsh-syntax-highlighting | zsh-syntax-highlighting |
| Completion | PSReadLine + posh-git | fzf-tab + zsh-completions | fzf-tab + zsh-completions |
| History | atuin synced | atuin synced | atuin synced |
| Aliases | inline functions | `~/.zsh/aliases.sh` | `~/.zsh/aliases.sh` |

### CLI utilities

| Tool | Purpose | Alias |
|---|---|---|
| eza | `ls` replacement | `ll`, `la`, `lt` |
| bat | `cat` replacement | `cat`, `less` |
| fd | `find` replacement | — |
| ripgrep | `grep` replacement | — *(`grep` stays literal)* |
| zoxide | smarter `cd` | `z`, `zi` *(`cd` stays literal)* |
| delta | git diff pager | wired in gitconfig |
| fzf | fuzzy finder | Ctrl-T file, Alt-C dir, Ctrl-R ceded to atuin |
| atuin | shell history | Ctrl-R |

### Visual

| Layer | Choice |
|---|---|
| Prompt | [Starship](https://starship.rs) — two-line, p10k-lean style |
| Font | JetBrains Mono Nerd Font + CJK fallback (Microsoft YaHei / PingFang SC) |
| Theme | Catppuccin Mocha (Cursor, bat, delta) |
| Terminal | OS-native (Windows Terminal / iTerm2 / Alacritty) |

### Package manager

| OS | Primary | Fallback |
|---|---|---|
| Windows | scoop | winget *(MSI quirk on machines with `wuauserv` disabled — use `msiexec /i` directly)* |
| macOS | Homebrew | — |
| Linux | distro (apt/dnf/pacman) | vendor installers for chezmoi/starship/gh |

### Git

| Setting | Value |
|---|---|
| Identity | templated from `chezmoi.toml` prompts |
| Commit signing | SSH (ed25519, auto-wires once `~/.ssh/id_ed25519` exists) |
| Pager | delta side-by-side, Catppuccin-mocha syntax theme |
| Conflict style | zdiff3 |
| Diff algorithm | histogram |
| Aliases | `lg`, `last`, `amend`, `undo` |

### Remote access & networking

| Feature | Profile | Notes |
|---|---|---|
| SSH config | core | private repo `qqgjyx/ssh-config`, single file + `Include` directive |
| SSH key | core | per-machine ed25519, passphrase-protected, ssh-agent |
| Mosh | dev | resilient SSH over UDP |
| Tailscale | dev | mesh VPN; `tailscale up` post-bootstrap (manual auth) |
| Clash Verge | full | GFW circumvention; config not version-controlled |

### Editor & writing

| Item | Detail |
|---|---|
| Editor | Cursor *(VS Code fork; settings format identical)* |
| Theme | Catppuccin Mocha + Catppuccin icons |
| Extensions | 14 base (Python, Ruff, Jupyter, GitLens, Git Graph, project-manager, errorlens, editorconfig, markdown-all-in-one, todo-tree, code-spell-checker, MS-CEINTL `zh-hans`, +Catppuccin theme & icons) |
| Extensions (full) | + James-Yu LaTeX Workshop |
| LaTeX (full) | TeX Live *basic* scheme; `latexmk` default recipe; `biber` for bib |

### AI tooling

| Item | Detail |
|---|---|
| `~/.claude/CLAUDE.md` | vendored verbatim from [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (universal LLM-coding principles; no personal identity) |
| `~/.claude/settings.json` | `autoUpdatesChannel: latest`, permissions `defaultMode: auto`, dangerous-mode + auto-permission prompts skipped |
| `~/.claude/skills/` | cloned from private `qqgjyx/skills` repo |
| Codex CLI | install only; no config tracked |

---

## Profiles

Pick at `chezmoi init` prompt (changeable later via `chezmoi edit-config`).

| Profile | Adds |
|---|---|
| `core` *(default)* | shell + ergonomics + CLI utilities + git + ssh + Cursor + AI tooling + package manager |
| `dev` | core + Mosh + Tailscale |
| `full` | dev + LaTeX (TeX Live basic) + Clash Verge |

---

## Layout

Top level:

```
dotfiles/
├── .chezmoiroot                  # points source root to ./home
├── LICENSE                       # MIT
├── .github/workflows/            # chezmoi-verify CI
├── bootstrap/{stage1,stage2}.{sh,ps1}
└── home/                         # chezmoi source state (see below)
```

<details>
<summary><strong>home/</strong> source state — full tree</summary>

```
home/
├── .chezmoi.toml.tmpl            # prompts for name/email/profile on init
├── .chezmoidata.toml             # static data (theme, extensions list)
├── .chezmoiignore                # OS-conditional skip rules
├── .chezmoiversion               # minimum chezmoi version
├── dot_zshrc.tmpl                # → ~/.zshrc
├── dot_bashrc.tmpl               # → ~/.bashrc
├── dot_gitconfig.tmpl            # → ~/.gitconfig
├── dot_gitignore_global          # → ~/.gitignore_global
├── dot_ripgreprc                 # → ~/.ripgreprc
├── dot_zsh_plugins.txt           # antidote bundle list
├── private_dot_zsh/aliases.sh
├── dot_config/
│   ├── starship.toml
│   ├── atuin/config.toml
│   ├── bat/config
│   └── Cursor/User/{settings,keybindings}.json
├── dot_claude/{CLAUDE.md, settings.json}
├── Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl
├── run_onchange_install-cursor.{sh,ps1}.tmpl
└── run_onchange_install-packages.{sh,ps1}.tmpl
```

</details>

---

## Maintenance

```bash
chezmoi diff             # preview what apply would change
chezmoi apply            # materialize source → home
chezmoi edit <file>      # edit source state, then apply
chezmoi update           # pull from origin + apply
chezmoi cd               # jump into the source dir
```

Per-machine overrides go in `*.local` sibling files (never committed):

| Managed file | Local override (sourced last) |
|---|---|
| `~/.zshrc` | `~/.zshrc.local` |
| `~/.bashrc` | `~/.bashrc.local` |
| PowerShell profile | `~/.powershell_profile.local.ps1` |

---

## Intentionally not included

Skip-list with reasons (re-evaluate when the need is real):

| Tool | Why skipped |
|---|---|
| direnv | `uv` covers per-project context switching for Python |
| mise / asdf | `uv` handles Python; Node/Bun/Rust installed globally |
| age encryption | private repos chosen instead for sensitive content |
| Marketplace plugin manifest | start empty; add `~/.claude/plugins.txt` as plugins are adopted |

---

## License

MIT — see [LICENSE](LICENSE).

`home/dot_claude/CLAUDE.md` is vendored from [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills); see that file's header comment for attribution.
