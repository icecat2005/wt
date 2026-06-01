# wt

`wt` is a tiny shell function that lets you **fzf-pick a git worktree** and jump
straight into it — or **create a new worktree + branch by name** — without
leaving your shell.

It assumes the worktree layout where a repo's worktrees live in a sibling
`<repo>.worktrees/` directory:

```
~/code/
├── myrepo/                 # main checkout
└── myrepo.worktrees/
    ├── feature-a/
    └── bugfix-b/
```

Run `wt` from anywhere inside the repo (or any of its worktrees) and pick from a
fuzzy list that includes `main` plus every worktree. Each entry shows the branch
currently checked out in that worktree in faded text (a detached HEAD shows as
`detached@<sha>`); the fuzzy search matches on the worktree name. Run
`wt add <name>` to create `myrepo.worktrees/<name>` on a branch named `<name>`
and drop into it.

The main checkout is found via `git worktree list` (its first entry is always
the primary worktree), so `wt` works correctly even when invoked from inside a
linked worktree.

## Why a shell function (not a binary)?

`wt` changes your current directory, so it has to run **in** your shell — a
binary on `$PATH` runs in a child process and can't `cd` the parent. That's why
installation sources a function into your shell rc instead of dropping a file on
`$PATH`.

## Requirements

- [`git`](https://git-scm.com/)
- [`fzf`](https://github.com/junegunn/fzf)
- `code` CLI — only for `wt -c` / `wt --code`
- bash or zsh, on Linux or macOS

## Install

One-liner:

```sh
curl -fsSL https://raw.githubusercontent.com/icecat2005/wt/main/install.sh | sh
```

Or from a clone:

```sh
git clone https://github.com/icecat2005/wt.git
cd wt
./install.sh
```

Then restart your shell (or `source` the printed path). The installer:

- copies `wt.sh` to `~/.local/share/wt/wt.sh` (respects `$XDG_DATA_HOME`)
- adds a source line to `~/.bashrc` and/or `~/.zshrc` (whichever exist)
- is idempotent — safe to re-run

## Update

Re-running the installer is safe and overwrites `wt.sh` in place. To do a
**clean** update — removing the old function file and rc source lines first,
then reinstalling fresh (useful if the install layout or rc wiring changed) —
pass `--update`:

```sh
# from a clone
./install.sh --update

# remote one-liner
curl -fsSL https://raw.githubusercontent.com/icecat2005/wt/main/install.sh | sh -s -- --update
```

> **macOS bash note:** login shells read `~/.bash_profile`, not `~/.bashrc`. If
> you use bash on macOS and `wt` isn't found in a new terminal, add
> `[ -f ~/.bashrc ] && . ~/.bashrc` to your `~/.bash_profile`. (zsh — the macOS
> default — works out of the box.)

## Usage

```
wt                 # fzf-pick a worktree and cd into it
wt -c              # fzf-pick a worktree and `code --add` it to VS Code
wt add <name>      # create <repo>.worktrees/<name> + branch <name>, then cd in
wt add -c <name>   # same, but `code --add` the new worktree to VS Code
wt -h              # help
```

`wt add` follows a four-case decision tree so it's safe to re-run (create-or-switch):

| branch exists? | worktree exists? | behaviour |
|---|---|---|
| no  | no  | create the worktree **and** the branch (`git worktree add <path> -b <name>`) |
| yes | no  | add a worktree checking out the existing branch (`git worktree add <path> <name>`) |
| no  | yes | create the branch inside the existing worktree (`git -C <path> switch -c <name>`) |
| yes | yes | nothing to create — just cd/open it |

## Manual install

If you'd rather not run the installer, just source `wt.sh` from your rc file:

```sh
. /path/to/wt.sh
```

## Uninstall

```sh
./uninstall.sh
```

Removes the function file and strips the source line from your rc files.

## Tests

The test harness spins up a throwaway repo, sources `wt.sh`, and asserts both
the switch and `wt add` behaviour. Run it under either shell:

```sh
zsh  test/wt.test.sh
bash test/wt.test.sh
```

## License

MIT — see [LICENSE](LICENSE).
