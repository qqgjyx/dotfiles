# Source machine-local overrides last so they win.
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
