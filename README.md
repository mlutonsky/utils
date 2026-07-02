# utils

A collection of small shell utilities.

> **Note:** Most of the code in this repository is AI-generated (with [Claude Code](https://claude.ai/code)) and human-reviewed.

## Scripts

| Script | Description |
|--------|-------------|
| [git-co](#git-co) | Fuzzy-matching git branch checkout with typo correction and interactive selection |
| [git-branch-clean](#git-branch-clean) | Prune stale remote refs and delete obsolete local branches (upstream gone, or untracked-and-merged) |
| [git-branch-close](#git-branch-close) | Fast-forward merge current branch into default branch, push, and delete it |
| [git-commit-msg](#git-commit-msg) | Generate a commit message from staged changes using Claude |
| [git-autocommit](#git-autocommit) | Split all working-tree changes into atomic commits using Claude; review the plan, then commit |
| [git-changelog](#git-changelog) | Draft the next CHANGELOG entry and version bump (patch/minor) using Claude; optionally release it |
| [neon2json](#neon2json) | Convert NEON (Nette Object Notation) to JSON, for LLMs and tools that don't speak NEON |

---

## Install all scripts

Run `install.sh` to symlink all scripts to `~/.local/bin/` in one command:

```sh
./install.sh
```

Use `--force` to overwrite existing symlinks:

```sh
./install.sh --force
```

`~/.local/bin/` is created automatically if it does not exist. Each script is
symlinked from the repository directory, so you can update scripts with a
`git pull` and the changes take effect immediately.

---

## git-co

**Fuzzy-matching git branch checkout.**

Checks out a branch by name. If the exact name is not found, falls back to fuzzy
matching and either auto-switches to the single closest match or presents a
numbered menu when multiple candidates exist.

**Fallback chain:** [fzf](https://github.com/junegunn/fzf) (if installed) → substring match → Levenshtein distance

### Usage

```
git-co <branch>
git-co -h | --help
```

### Examples

```sh
git-co main            # exact match — switches immediately
git-co feat/login      # tracks origin/feat/login if not local yet
git-co logn            # typo → finds 'feat/login', auto-checks out
git-co feat            # multiple matches → interactive numbered menu
```

### Install

Copy or symlink `git-co` to any directory on your `$PATH`:

```sh
ln -s "$PWD/git-co" ~/.local/bin/git-co
```

`fzf` is optional but recommended for better fuzzy matching.

---

## git-branch-clean

**Prune stale remote refs and delete obsolete local branches.**

Runs `git fetch --prune`, then deletes:

1. local branches whose upstream is gone (`: gone]` in `git branch -vv`), and
2. local branches with no upstream that are fully merged into the integration
   branch (resolved from `origin/HEAD`).

Safe to run routinely after merging or closing feature branches. Branches with
any local-only commits are kept (ancestry is checked with
`git merge-base --is-ancestor`).

### Usage

```
git-branch-clean [-h|--help]
```

### Example

```sh
$ git-branch-clean
Fetching and pruning...
Deleted branch feature/login (was abc1234).      # upstream was pruned
Deleted branch local-cleanup (was def5678).      # no upstream, merged into main
```

### Install

```sh
ln -s "$PWD/git-branch-clean" ~/.local/bin/git-branch-clean
```

---

## git-branch-close

**Fast-forward merge current branch into the default branch, push, and delete it.**

A single command to finish a feature branch: fast-forwards `main` (or `master`)
to the current branch, pushes to origin, and removes the branch locally and
remotely. The default branch is auto-detected from `origin/HEAD`; falls back to
checking for `main` then `master`. Refuses to proceed if a fast-forward is not
possible.

### Usage

```
git-branch-close [-h|--help]
```

### Example

```sh
$ git-branch-close
Closing branch: feature/login → main
Fetching latest changes...
Switching to main...
Fast-forwarding main to feature/login...
Pushing main to origin...
Branch feature/login successfully closed and merged into main.
```

### Install

```sh
ln -s "$PWD/git-branch-close" ~/.local/bin/git-branch-close
```

---

## git-commit-msg

**Generate a commit message from staged changes using Claude.**

Inspects the staged diff, asks Claude to draft a concise commit message in plain
imperative style, then opens your configured git editor pre-filled with the result
so you can review and edit before committing. Exits immediately if nothing is
staged.

### Usage

```
git-commit-msg [-h|--help]
```

### Example

```sh
$ git-commit-msg
Generating commit message...
# editor opens pre-filled with:
# Fix null pointer in auth middleware when session token is missing
```

### Requirements

- `claude` — Claude CLI (`npm install -g @anthropic-ai/claude-code` or see [claude.ai/code](https://claude.ai/code))

### Install

```sh
ln -s "$PWD/git-commit-msg" ~/.local/bin/git-commit-msg
```

---

## git-autocommit

**Split working-tree changes into atomic commits using Claude.**

Inspects **all** uncommitted changes — staged, unstaged, and untracked files —
and asks Claude to group them into a small set of atomic, semantically related
commits. After you **review and approve** the plan, it creates those commits in
order.

Every change is presented to Claude as an assignable unit: individual diff
**hunks** for tracked text files, and **whole files** for new (untracked) or
binary files. Claude assigns each unit to a commit and writes its message. When a
file's hunks are split across commits the tool performs hunk-level surgery
(`git apply --cached`); when all of a file's changes land in one commit it is
staged whole.

Nothing is committed until you approve the plan. If a partial patch cannot be
applied cleanly (e.g. two hunks bound for different commits sit too close
together), the tool **aborts and restores every change as uncommitted** — you
never end up in a half-committed state. The tool manages staging itself: it
unstages everything before it starts, so your prior staging selection is not
preserved.

### Usage

```
git-autocommit [-h|--help]
```

### Example output

```sh
$ git-autocommit
Asking Claude to group 4 hunk(s) and 1 whole file(s) into commits...

Plan: 3 commit(s)

[1] Add login() helper
      src/auth.js  (H1)
[2] Fix greeting typo
      src/app.js   (H3)
      README.md    (whole file)
[3] Add usage notes
      NOTES.md     (new file)

Create these commits? [y/N] y
Committed [1/3] Add login() helper
Committed [2/3] Fix greeting typo
Committed [3/3] Add usage notes

Done — created 3 commit(s).
```

### Requirements

- `git`
- `claude` — Claude CLI (`npm install -g @anthropic-ai/claude-code` or see [claude.ai/code](https://claude.ai/code))
- `jq` — parses Claude's JSON commit plan

### Install

```sh
ln -s "$PWD/git-autocommit" ~/.local/bin/git-autocommit
```

---

## git-changelog

**Draft the next CHANGELOG entry and version bump using Claude.**

Collects the commits and diff since the last release tag, sends them to Claude
together with the previous version, and asks it to draft the next
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) entry and to suggest the
next [Semantic Versioning](https://semver.org/) bump — **patch** or **minor**,
never major (major releases are cut manually). The proposed entry is opened in
your editor **before** `CHANGELOG.md` is touched, so you can confirm, reword, or
change the version; it is inserted at the top of `CHANGELOG.md` only after you save.

By default both **committed** changes since the baseline **and** the current
**uncommitted** (staged + unstaged) changes and untracked files are considered —
useful when you prepare the `CHANGELOG.md` edit together with the changes it
describes, in a single commit. Pass `--committed-only` to restrict to changes that
are already committed.

The version is taken from the `## [x.y.z] - date` header line you save, so you can
override Claude's suggested bump just by editing that number — both candidate
versions (patch and minor) are printed before the editor opens so you know what to
type. If a section for that version is already in `CHANGELOG.md` (e.g. you ran the
tool earlier without tagging and re-run it keeping the same version), the existing
section is **replaced in place** instead of being duplicated.

Pass `--unreleased` (`-u`) to skip the version step entirely: instead of a
`## [x.y.z] - date` entry, the changes are drafted into a `## [Unreleased]` section
at the top of the changelog. If that section already exists, Claude **merges** the
new bullets into it and **de-duplicates**, so running it repeatedly as you work
converges instead of restating everything. Use it to accumulate notes between
releases; cut the real versioned entry later with a normal run. Cannot be combined
with `--release`.

With `--release` it also commits `CHANGELOG.md`, creates the release tag (mirroring
the repo's existing tag prefix, e.g. `v`), and pushes the commit and tag to origin.
The annotated tag's message is the changelog entry itself. When uncommitted changes
are included (the default), the release commit **bundles all your working-tree
changes** together with the `CHANGELOG.md` update, and its message is **generated by
the sibling [`git-commit-msg`](#git-commit-msg)** helper (which opens an editor to
confirm/edit, and also sees the changelog diff as a hint) — falling back to
`Release <version>` if that script isn't installed. With `--committed-only` the
commit contains only the changelog, so it is messaged `Release <version>`. Use
`-m/--message` to set the message explicitly (and non-interactively).

### Usage

```
git-changelog [options]
```

| Option | Description |
|--------|-------------|
| `-r, --release` | Commit `CHANGELOG.md`, create the release tag, and push both |
| `--no-push` | With `--release`, commit and tag locally but do not push |
| `--committed-only` | Ignore uncommitted changes; consider only committed changes |
| `-u, --unreleased` | Update/create the `## [Unreleased]` section instead of a versioned entry; skip the bump |
| `-m, --message <msg>` | Use `<msg>` as the release commit message (skips generation) |
| `--no-diff` | Send only commit messages + diffstat to Claude (skip the full diff) |
| `-y, --yes` | Skip the confirmation prompt before releasing |
| `--from <ref>` | Use `<ref>` as the previous release instead of the latest tag |
| `-f, --file <path>` | Changelog file to update (default: `CHANGELOG.md` in repo root) |
| `-h, --help` | Show the help message |

### Examples

```sh
git-changelog                     # draft from committed + uncommitted changes, edit, insert
git-changelog --unreleased        # draft/merge a "## [Unreleased]" section, no version bump
git-changelog --committed-only    # consider only already-committed changes
git-changelog --release           # bundle changes + CHANGELOG; commit msg via git-commit-msg; tag; push
git-changelog -r -m "Add X"       # bundled release with an explicit commit message
git-changelog --committed-only -r # CHANGELOG-only release commit (msg "Release x.y.z"), tag, push
git-changelog --from v3.12.0      # baseline against v3.12.0 instead of latest tag
```

### Example output

```sh
$ git-changelog
Baseline: v1.2.0 (current version 1.2.0), 2 commit(s) since + uncommitted working-tree changes.
Asking Claude to draft the changelog...

Suggested bump: minor
  patch → 1.2.1
  minor → 1.3.0   (suggested)
Reason: Adds a new login() helper — new user-facing functionality.

The version in the editor's '## [...]' header decides the release — change it
to the other candidate (or anything) to override the suggested bump.

Opening editor — adjust the version/date and entries, save to continue (empty = abort).
# editor opens pre-filled with:
# ## [1.3.0] - 2026-05-30
# ### Added
# - `login()` helper to authenticate users
# ### Fixed
# - greeting typo in app output
```

### Requirements

- `git`
- `claude` — Claude CLI (`npm install -g @anthropic-ai/claude-code` or see [claude.ai/code](https://claude.ai/code))
- `git-commit-msg` — optional sibling script; if present, generates the message for bundled release commits

### Install

```sh
ln -s "$PWD/git-changelog" ~/.local/bin/git-changelog
```

---

## neon2json

**Convert NEON (Nette Object Notation) to JSON.**

Parses NEON from a file argument or stdin using Nette's NEON library and prints
the corresponding JSON to stdout. Useful for feeding Nette config files into
LLMs and other tools that don't know the NEON format.

DateTime values are rendered as ISO 8601 strings. NEON entities (e.g.
`Service(arg: 1)`) are rendered as objects with `__neon_entity: true`, `value`,
and `attributes` keys.

### Usage

```
neon2json [-h|--help] [file]
```

### Examples

```sh
neon2json config.neon                # read file
cat config.neon | neon2json          # read stdin
neon2json < config.neon              # read stdin
```

### Requirements

- `php` — PHP 8.1+
- `composer` — run `composer install` in this repo to fetch `nette/neon`

### Install

```sh
composer install
ln -s "$PWD/neon2json" ~/.local/bin/neon2json
```

---

## License

[MIT](LICENSE) © Martin Lutonsky
