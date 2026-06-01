#!/usr/bin/env sh
# Installer for `wt` — the fzf worktree switcher.
#
# Usage:
#   Local (from a clone):   ./install.sh
#   Remote (one-liner):     curl -fsSL https://raw.githubusercontent.com/icecat2005/wt/main/install.sh | sh
#
#   Update (clean reinstall):
#     Local:                ./install.sh --update
#     Remote:               curl -fsSL .../install.sh | sh -s -- --update
#
# Installs wt.sh into $XDG_DATA_HOME/wt (default ~/.local/share/wt) and adds a
# source line to your shell rc files (.bashrc and/or .zshrc). Idempotent — safe
# to re-run. --update first removes the old function file and rc source lines,
# then reinstalls fresh. Works on Linux and macOS, in bash and zsh.

set -eu

REPO_RAW="https://raw.githubusercontent.com/icecat2005/wt/main"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wt"
FUNC_FILE="$INSTALL_DIR/wt.sh"
RC_COMMENT='# wt — fzf worktree switcher'

info() { printf 'wt: %s\n' "$1"; }

usage() {
  cat <<EOF
install.sh — install or update wt (the fzf worktree switcher)

Usage:
  ./install.sh              install (or idempotently re-install) wt
  ./install.sh --update     clean reinstall: remove old version + rc lines, then install
  ./install.sh --help       show this help

Remote equivalents:
  curl -fsSL $REPO_RAW/install.sh | sh
  curl -fsSL $REPO_RAW/install.sh | sh -s -- --update
EOF
}

# Parse args.
UPDATE=0
for arg in "$@"; do
  case "$arg" in
    -u|--update|update) UPDATE=1 ;;
    -h|--help)          usage; exit 0 ;;
    *) info "unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

# Remove a previous install: strip rc source lines and delete the install dir.
# Used by --update so stale settings (even in an old format) don't linger.
clean_previous() {
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    if grep -qF "$FUNC_FILE" "$rc" 2>/dev/null; then
      tmp="$rc.wt.tmp"
      # Drop our comment + source line, then trim trailing blank lines so the
      # blank separator we prepend on reinstall can't accumulate across updates.
      grep -vF "$FUNC_FILE" "$rc" | grep -vF "$RC_COMMENT" \
        | awk 'NF{last=NR} {line[NR]=$0} END{for(i=1;i<=last;i++) print line[i]}' \
        > "$tmp" || true
      mv "$tmp" "$rc"
      info "update: stripped old source line from $rc"
    fi
  done
  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    info "update: removed old $INSTALL_DIR"
  fi
}

if [ "$UPDATE" -eq 1 ]; then
  info "updating — removing any previous install first"
  clean_previous
fi

mkdir -p "$INSTALL_DIR"

# Resolve the directory this script lives in (when run from a clone).
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || true)

if [ -n "${SCRIPT_DIR:-}" ] && [ -f "$SCRIPT_DIR/wt.sh" ]; then
  cp "$SCRIPT_DIR/wt.sh" "$FUNC_FILE"
  info "installed from local copy"
else
  if ! command -v curl >/dev/null 2>&1; then
    info "curl is required for remote install" >&2
    exit 1
  fi
  curl -fsSL "$REPO_RAW/wt.sh" -o "$FUNC_FILE"
  info "downloaded wt.sh"
fi

info "function file -> $FUNC_FILE"

# Source line added to rc files. grep keys on $FUNC_FILE for idempotency.
LINE=". \"$FUNC_FILE\""

add_to_rc() {
  rc="$1"
  if grep -qF "$FUNC_FILE" "$rc" 2>/dev/null; then
    info "already wired into $rc"
    return 0
  fi
  printf '\n%s\n%s\n' "$RC_COMMENT" "$LINE" >> "$rc"
  info "added source line to $rc"
}

# Wire into every rc file that already exists.
WIRED=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ]; then
    add_to_rc "$rc"
    WIRED=1
  fi
done

# If neither exists, create one based on the user's login shell.
if [ "$WIRED" -eq 0 ]; then
  case "${SHELL:-}" in
    *zsh) rc="$HOME/.zshrc" ;;
    *)    rc="$HOME/.bashrc" ;;
  esac
  add_to_rc "$rc"
fi

# Friendly dependency check (non-fatal).
for dep in git fzf; do
  command -v "$dep" >/dev/null 2>&1 || info "note: '$dep' not found — wt needs it at runtime"
done

if [ "$UPDATE" -eq 1 ]; then
  info "update complete. Restart your shell or run:  . $FUNC_FILE"
else
  info "done. Restart your shell or run:  . $FUNC_FILE"
fi
