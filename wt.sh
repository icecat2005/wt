# wt — fzf-pick a git worktree to switch to, or create a new one by name.
# Defines the shell function `wt`. Source this file from your shell rc
# (e.g. ~/.bashrc or ~/.zshrc). Works in bash and zsh, on Linux and macOS.
#
# Worktrees live in a sibling `<repo>.worktrees/` directory (dot convention):
#
#   ~/code/
#   ├── myrepo/                 # main checkout
#   └── myrepo.worktrees/
#       ├── feature-a/
#       └── bugfix-b/

# Resolve the main repo + its worktrees dir. Sets _WT_MAIN_REPO and
# _WT_WORKTREES_DIR. Prints a message and returns non-zero on failure.
#
# The main repo is the first entry of `git worktree list --porcelain` (always
# the primary worktree), so this is correct even when run from inside a linked
# worktree, and is convention-agnostic for finding the main checkout.
_wt_resolve_paths() {
  if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' 'wt requires git'
    return 1
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' 'wt must be run inside a git repository'
    return 1
  fi
  _WT_MAIN_REPO="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
  _WT_WORKTREES_DIR="${_WT_MAIN_REPO}.worktrees"
}

# Create (or switch into) a worktree + branch named "$1". Mirrors the
# `/worktree` slash command's four-case decision tree. "$2" is the post-action
# mode: 'cd' (default) or 'code'.
_wt_add() {
  local name="$1" mode="$2"
  if [[ -z "$name" ]]; then
    printf '%s\n' 'usage: wt add <name>'
    return 1
  fi

  local wt_path="${_WT_WORKTREES_DIR}/${name}"
  local branch_exists=0 worktree_exists=0
  git show-ref --verify --quiet "refs/heads/${name}" && branch_exists=1
  git worktree list --porcelain | grep -qxF "worktree ${wt_path}" && worktree_exists=1

  if (( branch_exists && worktree_exists )); then
    # Case 1 — both exist → nothing to create, just act on it.
    printf "wt: branch '%s' and worktree '%s' already exist\n" "$name" "$wt_path"
  elif (( branch_exists )); then
    # Case 2 — branch exists, worktree missing → add a worktree on that branch.
    git worktree add "$wt_path" "$name" || return 1
  elif (( worktree_exists )); then
    # Case 3 — worktree exists, branch missing → create the branch in it.
    git -C "$wt_path" switch -c "$name" || return 1
  else
    # Case 4 — neither exists → create the worktree and the branch together.
    git worktree add "$wt_path" -b "$name" || return 1
  fi

  if [[ ! -d "$wt_path" ]]; then
    printf 'wt: worktree path not found after create: %s\n' "$wt_path"
    return 1
  fi

  case "$mode" in
    cd)   cd "$wt_path" || return 1 ;;
    code) code --add "$wt_path" ;;
  esac
}

# Print the branch checked out in the worktree at "$1" (empty if it can't be
# read). A detached HEAD reports as "HEAD", which we render as "detached@<sha>".
# Note: the local is named `dir`, not `path` — in zsh `path` is tied to $PATH,
# so `local path=...` would clobber PATH and make `git` unfindable.
_wt_branch_of() {
  local dir="$1" branch
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$branch" == 'HEAD' ]]; then
    branch="detached@$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
  fi
  printf '%s' "$branch"
}

# fzf-pick an existing worktree (or 'main') and act on it. "$1" is the mode:
# 'cd' (default) or 'code'.
_wt_switch() {
  local mode="$1"
  if ! command -v fzf >/dev/null 2>&1; then
    printf '%s\n' 'wt requires fzf'
    return 1
  fi
  if [[ ! -d "$_WT_WORKTREES_DIR" ]]; then
    printf 'wt could not find %s\n' "$_WT_WORKTREES_DIR"
    return 1
  fi

  local dim=$'\033[2m' reset=$'\033[0m'
  local selected_line selected_name selected_path
  # Each row is "<name>\t<dim>branch<reset>": the branch is shown faded for
  # context only. fzf searches just the name field (--nth=1) and renders the
  # ANSI dim (--ansi); we parse the name back out by cutting at the tab.
  # Portable basename listing: GNU find's -printf '%f' is unavailable on
  # macOS/BSD find, so strip the leading path with sed instead.
  selected_line="$({
    if [[ -d "$_WT_MAIN_REPO" ]]; then
      printf '%s\t%s%s%s\n' 'main' "$dim" "$(_wt_branch_of "$_WT_MAIN_REPO")" "$reset"
    fi
    find "$_WT_WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's:.*/::' | while IFS= read -r _wt_name; do
      printf '%s\t%s%s%s\n' "$_wt_name" "$dim" "$(_wt_branch_of "$_WT_WORKTREES_DIR/$_wt_name")" "$reset"
    done
  } | sort | fzf --ansi --delimiter=$'\t' --nth=1 --prompt='worktree> ' --height=40% --reverse)"

  if [[ -z "$selected_line" ]]; then
    return 1
  fi

  # Keep the first match, then take the name (everything before the tab).
  selected_line="${selected_line%%$'\n'*}"
  selected_name="${selected_line%%$'\t'*}"

  if [[ "$selected_name" == 'main' ]]; then
    selected_path="$_WT_MAIN_REPO"
  else
    selected_path="$_WT_WORKTREES_DIR/$selected_name"
  fi

  if [[ ! -d "$selected_path" ]]; then
    printf 'wt selected path no longer exists: %s\n' "$selected_path"
    return 1
  fi

  case "$mode" in
    cd)   cd "$selected_path" || return 1 ;;
    code) code --add "$selected_path" ;;
  esac
}

wt() {
  local mode='cd' subcmd='switch' name=''

  if [[ "$1" == 'add' ]]; then
    subcmd='add'
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--code)
        mode='code'
        shift
        ;;
      -h|--help)
        printf '%s\n' \
          'wt [add <name>] [option]' \
          '' \
          'Switch between, or create, git worktrees under <repo>.worktrees/.' \
          '' \
          'Usage:' \
          '  wt                 fzf-pick a worktree and cd into it' \
          '  wt -c, --code      fzf-pick a worktree and add it to the active VS Code window' \
          '  wt add <name>      create <repo>.worktrees/<name> + branch <name>, then cd into it' \
          '  wt add -c <name>   same, but add the new worktree to the active VS Code window' \
          '  wt -h, --help      show this help'
        return 0
        ;;
      -*)
        printf 'wt: unknown option: %s\n' "$1"
        return 1
        ;;
      *)
        if [[ "$subcmd" == 'add' && -z "$name" ]]; then
          name="$1"
          shift
        else
          printf 'wt: unexpected argument: %s\n' "$1"
          return 1
        fi
        ;;
    esac
  done

  if [[ "$mode" == 'code' ]] && ! command -v code >/dev/null 2>&1; then
    printf '%s\n' 'wt -c requires the VS Code "code" command'
    return 1
  fi

  _wt_resolve_paths || return 1

  if [[ "$subcmd" == 'add' ]]; then
    _wt_add "$name" "$mode"
  else
    _wt_switch "$mode"
  fi
}
