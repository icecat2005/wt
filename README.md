# wt

`wt` is a tiny shell function that lets you **fzf-pick a git worktree** and jump
straight into it — or open it in VS Code.

It assumes the worktree layout where a repo's worktrees live in a sibling
`<repo>-worktrees/` directory:

```
~/code/
├── myrepo/                 # main checkout
└── myrepo-worktrees/
    ├── feature-a/
    └── bugfix-b/
```

Run `wt` from anywhere inside the repo (or any of its worktrees) and pick from a
fuzzy list that includes `main` plus every worktree.

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

> **macOS bash note:** login shells read `~/.bash_profile`, not `~/.bashrc`. If
> you use bash on macOS and `wt` isn't found in a new terminal, add
> `[ -f ~/.bashrc ] && . ~/.bashrc` to your `~/.bash_profile`. (zsh — the macOS
> default — works out of the box.)

## Usage

```
wt            # fzf-pick a worktree and cd into it
wt -c         # fzf-pick a worktree and `code --add` it to VS Code
wt -h         # help
```

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

## License

MIT — see [LICENSE](LICENSE).
