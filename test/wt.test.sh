#!/usr/bin/env bash
# Test harness for wt.sh. Runs under both bash and zsh:
#   zsh  test/wt.test.sh
#   bash test/wt.test.sh
#
# Spins up a throwaway git repo with the dot-worktrees layout, sources wt.sh,
# and asserts behaviour. `wt` cds the *current* shell, so cd-sensitive checks
# run wt with stdout redirected to a file (not in a $() subshell, which would
# discard the cd).

WT_SH="$(cd "$(dirname "$0")/.." && pwd)/wt.sh"

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1"; printf '       expected: %s\n       actual:   %s\n' "$2" "$3"; fi
}
assert_contains() { # desc haystack needle
  if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1"; printf '       missing %q in: %s\n' "$3" "$2"; fi
}
assert_ok() { # desc rc
  if [[ "$2" -eq 0 ]]; then ok "$1"; else bad "$1 (rc=$2)"; fi
}
assert_nonzero() { # desc rc
  if [[ "$2" -ne 0 ]]; then ok "$1"; else bad "$1 (rc=$2)"; fi
}

# --- Syntax checks ---------------------------------------------------------
printf 'Syntax checks:\n'
if command -v zsh  >/dev/null 2>&1; then zsh  -n "$WT_SH" && ok 'zsh -n wt.sh'  || bad 'zsh -n wt.sh';  else printf '  skip zsh (not found)\n';  fi
if command -v bash >/dev/null 2>&1; then bash -n "$WT_SH" && ok 'bash -n wt.sh' || bad 'bash -n wt.sh'; else printf '  skip bash (not found)\n'; fi

# --- Fixture ---------------------------------------------------------------
# Physicalize the path: on macOS mktemp returns /var/... but /var symlinks to
# /private/var, and git's porcelain reports the resolved path. Resolving here
# keeps expected paths in step with git (see design doc §7).
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/myrepo"
WTDIR="$TMP/myrepo.worktrees"
mkdir -p "$REPO"
cd "$REPO"
git init -q -b main
git config user.email 't@example.com'
git config user.name  'test'
git commit -q --allow-empty -m init

# shellcheck disable=SC1090
. "$WT_SH"

OUT="$TMP/out.txt"

printf '\nCreate — Case 4 (neither branch nor worktree exists):\n'
cd "$REPO"
wt add feat-x >"$OUT" 2>&1; rc=$?
assert_ok       'wt add feat-x exits 0' "$rc"
assert_eq       'cd into new worktree'  "$WTDIR/feat-x" "$PWD"
git -C "$REPO" show-ref --verify --quiet refs/heads/feat-x; assert_ok 'branch feat-x created' $?
[[ -d "$WTDIR/feat-x" ]]; assert_ok 'worktree dir feat-x exists' $?

printf '\nCreate — Case 1 (both exist, idempotent):\n'
cd "$REPO"
wt add feat-x >"$OUT" 2>&1; rc=$?
assert_ok       'wt add feat-x (again) exits 0' "$rc"
assert_contains 'prints already-exist message' "$(cat "$OUT")" 'already exist'
assert_eq       'still cds into worktree'       "$WTDIR/feat-x" "$PWD"

printf '\nCreate — Case 2 (branch exists, worktree missing):\n'
cd "$REPO"
git branch feat-y
wt add feat-y >"$OUT" 2>&1; rc=$?
assert_ok 'wt add feat-y exits 0' "$rc"
assert_eq 'cd into worktree for existing branch' "$WTDIR/feat-y" "$PWD"
assert_eq 'worktree checks out feat-y' 'feat-y' "$(git -C "$WTDIR/feat-y" rev-parse --abbrev-ref HEAD)"

printf '\nCreate — Case 3 (worktree exists, branch missing):\n'
cd "$REPO"
git worktree add -q "$WTDIR/feat-z" -b scratch-z
wt add feat-z >"$OUT" 2>&1; rc=$?
assert_ok 'wt add feat-z exits 0' "$rc"
assert_eq 'cd into the existing worktree' "$WTDIR/feat-z" "$PWD"
assert_eq 'branch switched to feat-z' 'feat-z' "$(git -C "$WTDIR/feat-z" rev-parse --abbrev-ref HEAD)"

printf '\nSwitch — from main into a worktree:\n'
cd "$REPO"
FZF_DEFAULT_OPTS='--filter=feat-x' wt >"$OUT" 2>&1; rc=$?
assert_ok 'switch exits 0' "$rc"
assert_eq 'cd into filtered worktree' "$WTDIR/feat-x" "$PWD"

printf '\nSwitch — back to main from inside a worktree:\n'
cd "$WTDIR/feat-x"
FZF_DEFAULT_OPTS='--filter=main' wt >"$OUT" 2>&1; rc=$?
assert_ok 'switch exits 0' "$rc"
assert_eq 'cd back to main checkout' "$REPO" "$PWD"

printf '\nErrors:\n'
cd "$TMP"   # not a git repo
out="$(wt 2>&1)"; rc=$?
assert_nonzero  'outside a repo is an error' "$rc"
assert_contains 'outside-repo message' "$out" 'must be run inside a git repository'

out="$(wt add 2>&1)"; rc=$?
assert_nonzero  'wt add with no name is an error' "$rc"

# fzf missing: restricted PATH with git + awk only (enough to resolve paths,
# then the switch path should bail on the fzf check).
mkdir -p "$TMP/bin"
ln -s "$(command -v git)" "$TMP/bin/git"
ln -s "$(command -v awk)" "$TMP/bin/awk"
cd "$REPO"
SAVED_PATH="$PATH"
PATH="$TMP/bin"
out="$(wt 2>&1)"; rc=$?
PATH="$SAVED_PATH"
assert_nonzero  'missing fzf is an error' "$rc"
assert_contains 'fzf-required message' "$out" 'wt requires fzf'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
