#!/usr/bin/env bash
# Idempotent symlink installer for POSIX (Git Bash, macOS, Linux).
# Backs up existing real files to *.dotfiles-bak before linking.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SRC="$DOTFILES/home"

# On Git Bash for Windows, request real symlinks instead of copies.
case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) export MSYS=winsymlinks:nativestrict ;;
esac

link() {
	local src="$1" dst="$2"
	if [ -L "$dst" ]; then
		# Already a symlink — re-point it.
		rm "$dst"
	elif [ -e "$dst" ]; then
		mv "$dst" "$dst.dotfiles-bak.$(date +%Y%m%d%H%M%S)"
	fi
	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	echo "linked  $dst -> $src"
}

# Symlink everything in home/ into $HOME (dotfiles included).
shopt -s dotglob nullglob
for src in "$HOME_SRC"/*; do
	link "$src" "$HOME/$(basename "$src")"
done

echo "done."
