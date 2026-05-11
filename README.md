# dotfiles

Personal configuration for [@qqgjyx](https://github.com/qqgjyx).

Designed to work on:
- **Windows 11** with Git Bash + PowerShell (current daily driver)
- **macOS / Linux** (planned, once I move to Harvard)

## Layout

```
dotfiles/
├── home/         # Symlinked into $HOME on POSIX (and via PowerShell on Windows)
│   ├── .gitconfig
│   └── .bashrc
├── win/          # Windows-specific targets
│   └── Microsoft.PowerShell_profile.ps1
├── bootstrap.sh  # POSIX installer (Git Bash, macOS, Linux)
└── bootstrap.ps1 # Windows installer — run from elevated PowerShell
```

## Bootstrap

**Windows** (PowerShell as Administrator):
```powershell
cd $HOME\dotfiles
.\bootstrap.ps1
```

**POSIX** (Git Bash, macOS, Linux):
```bash
cd ~/dotfiles && ./bootstrap.sh
```

Both scripts are idempotent: re-run them anytime to repair links.

## Per-machine overrides

Anything that should *not* be in version control (work-specific paths,
private aliases, secrets) goes in sibling `*.local` files that the main
configs source last:

| Main config                               | Local override                       |
| ----------------------------------------- | ------------------------------------ |
| `~/.bashrc`                               | `~/.bashrc.local`                    |
| `~/Documents/PowerShell/profile.ps1` etc. | `~/.powershell_profile.local.ps1`    |

`*.local` is in `.gitignore`.

## What's intentionally *not* here yet

Add only when there's a real need. Resist the urge to pre-configure.
