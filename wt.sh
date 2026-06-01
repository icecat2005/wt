# wt — fzf-pick a git worktree and act on it.
# Defines the shell function `wt`. Source this file from your shell rc
# (e.g. ~/.bashrc or ~/.zshrc). Works in bash and zsh, on Linux and macOS.

wt() {
  local mode='cd'

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--code)
        mode='code'
        shift
        ;;
      -h|--help)
        printf '%s\n' \
          'wt [option]' \
          '' \
          'fzf-pick a worktree and act on it.' \
          '' \
          'Options:' \
          '  (none)        cd into the selected worktree' \
          '  -c, --code    add the selected worktree to the active VS Code window' \
          '  -h, --help    show this help'
        return 0
        ;;
      *)
        printf 'wt: unknown option: %s\n' "$1"
        return 1
        ;;
    esac
  done

  if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' 'wt requires git'
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    printf '%s\n' 'wt requires fzf'
    return 1
  fi

  if [[ "$mode" == 'code' ]] && ! command -v code >/dev/null 2>&1; then
    printf '%s\n' 'wt -c requires the VS Code "code" command'
    return 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf '%s\n' 'wt must be run inside a git repository'
    return 1
  }

  local repo_parent repo_name main_repo worktrees_dir
  repo_parent="$(dirname "$repo_root")"
  repo_name="$(basename "$repo_root")"

  if [[ "$(basename "$repo_parent")" == *-worktrees ]]; then
    worktrees_dir="$repo_parent"
    repo_name="${repo_parent##*/}"
    repo_name="${repo_name%-worktrees}"
    main_repo="$(dirname "$repo_parent")/$repo_name"
  else
    main_repo="$repo_root"
    worktrees_dir="$repo_parent/${repo_name}-worktrees"
  fi

  if [[ ! -d "$worktrees_dir" ]]; then
    printf 'wt could not find %s\n' "$worktrees_dir"
    return 1
  fi

  local selected_name selected_path
  # Portable basename listing: GNU find's -printf '%f' is unavailable on
  # macOS/BSD find, so strip the leading path with sed instead.
  selected_name="$({
    if [[ -d "$main_repo" ]]; then
      printf '%s\n' 'main'
    fi
    find "$worktrees_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's:.*/::'
  } | sort | fzf --prompt='worktree> ' --height=40% --reverse)"

  if [[ -z "$selected_name" ]]; then
    return 1
  fi

  if [[ "$selected_name" == 'main' ]]; then
    selected_path="$main_repo"
  else
    selected_path="$worktrees_dir/$selected_name"
  fi

  if [[ ! -d "$selected_path" ]]; then
    printf 'wt selected path no longer exists: %s\n' "$selected_path"
    return 1
  fi

  case "$mode" in
    cd)
      cd "$selected_path" || return 1
      ;;
    code)
      code --add "$selected_path"
      ;;
  esac
}
