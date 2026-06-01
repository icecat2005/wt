#!/usr/bin/env sh
# Uninstaller for `wt`. Removes the installed function file and strips the
# source line from your shell rc files. Idempotent.

set -eu

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wt"
FUNC_FILE="$INSTALL_DIR/wt.sh"

info() { printf 'wt: %s\n' "$1"; }

# Remove the source line (and its preceding comment) from rc files.
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if grep -qF "$FUNC_FILE" "$rc" 2>/dev/null; then
    tmp="$rc.wt.tmp"
    grep -vF "$FUNC_FILE" "$rc" | grep -vF '# wt — fzf worktree switcher' > "$tmp"
    mv "$tmp" "$rc"
    info "removed source line from $rc"
  fi
done

if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  info "removed $INSTALL_DIR"
fi

info "done. The wt function stays defined in current shells until you restart them."
