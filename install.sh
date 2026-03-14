#!/bin/bash
# install.sh — install all scripts to ~/.local/bin via symlinks
#
# Symlinks each utility script to ~/.local/bin/ so they are available on
# your PATH. Creates ~/.local/bin/ if it does not already exist. Skips any
# script whose symlink already exists unless -f/--force is given.
#
# Usage:
#   install.sh [-h|--help] [-f|--force]
#
# Options:
#   -f, --force   Overwrite existing symlinks
#   -h, --help    Show this help message
#
# Examples:
#   ./install.sh           # install all scripts, skip existing symlinks
#   ./install.sh --force   # install all scripts, overwrite existing symlinks

_print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

FORCE=0

case "$1" in
  -h|--help) _print_help; exit 0 ;;
  -f|--force) FORCE=1 ;;
  "")  ;;
  *) echo "fatal: unknown option: $1"; exit 1 ;;
esac

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SCRIPTS=(git-co git-branch-clean git-branch-close idle-power-manager.sh)

if [ ! -d "$BIN_DIR" ]; then
  mkdir -p "$BIN_DIR"
  echo "Created $BIN_DIR"
fi

installed=0
skipped=0

for script in "${SCRIPTS[@]}"; do
  src="$REPO_DIR/$script"
  dest="$BIN_DIR/$script"

  if [ ! -f "$src" ]; then
    echo "fatal: script not found: $src"
    exit 1
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" -eq 1 ]; then
      ln -sf "$src" "$dest"
      echo "Reinstalled $script"
      installed=$((installed + 1))
    else
      echo "Skipped $script (already exists; use --force to overwrite)"
      skipped=$((skipped + 1))
    fi
  else
    ln -s "$src" "$dest"
    echo "Installed $script"
    installed=$((installed + 1))
  fi
done

echo ""
echo "$installed script(s) installed, $skipped skipped."
