# utils

A collection of small shell utilities.

> **Note:** Most of the code in this repository is AI-generated (with [Claude Code](https://claude.ai/code)) and human-reviewed.

## Scripts

| Script | Description |
|--------|-------------|
| [git-co](#git-co) | Fuzzy-matching git branch checkout with typo correction and interactive selection |
| [git-branch-clean](#git-branch-clean) | Prune stale remote refs and delete obsolete local branches (upstream gone, or untracked-and-merged) |
| [git-branch-close](#git-branch-close) | Fast-forward merge current branch into default branch, push, and delete it |
| [git-commit-msg](#git-commit-msg) | Generate a commit message from staged (or unstaged) changes using Claude |
| [git-changelog](#git-changelog) | Draft the next CHANGELOG entry and version bump (patch/minor) using Claude; optionally release it |
| [idle-power-manager.sh](#idle-power-managersh) | Automatic CPU power profile switcher based on GNOME idle detection |
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

**Generate a commit message from staged (or unstaged) changes using Claude.**

Inspects the current diff (staged changes first; falls back to all unstaged changes
if nothing is staged), asks Claude to draft a concise commit message in plain
imperative style, then opens your configured git editor pre-filled with the result
so you can review and edit before committing.

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
type.

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
| `-m, --message <msg>` | Use `<msg>` as the release commit message (skips generation) |
| `--no-diff` | Send only commit messages + diffstat to Claude (skip the full diff) |
| `-y, --yes` | Skip the confirmation prompt before releasing |
| `--from <ref>` | Use `<ref>` as the previous release instead of the latest tag |
| `-f, --file <path>` | Changelog file to update (default: `CHANGELOG.md` in repo root) |
| `-h, --help` | Show the help message |

### Examples

```sh
git-changelog                     # draft from committed + uncommitted changes, edit, insert
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

## idle-power-manager.sh

**Automatic CPU power profile switcher based on idle detection.**

Monitors user activity via GNOME Mutter DBus (Wayland-native, no sudo needed).
Switches to a powersave [tuned](https://tuned-project.org/) profile after a
configurable idle timeout. The profile that was active right before going idle
is remembered and restored as soon as activity is detected — so whatever mode
you were using (e.g. `balanced`) comes back on wake. Set `PERFORMANCE_PROFILE`
to force a fixed profile instead.

**Requirements:** `gdbus` (glib2), `tuned` + `tuned-adm`, GNOME session (Wayland), `wheel` group membership

### Usage

```
idle-power-manager.sh [-h|--help]
IDLE_THRESHOLD_MINS=20 idle-power-manager.sh
```

### Configuration

All settings are controlled via environment variables:

| Variable             | Default                                        | Description                                     |
|----------------------|------------------------------------------------|-------------------------------------------------|
| `IDLE_THRESHOLD_MINS`| `15`                                           | Minutes of inactivity before switching profiles |
| `PERFORMANCE_PROFILE`| remembered profile from before idle            | Force a fixed profile on wake instead of restoring |
| `IDLE_PROFILE`       | `powersave`                                    | Profile to apply when idle                      |
| `CHECK_INTERVAL`     | `30`                                           | Seconds between idle checks                     |
| `WAKE_THRESHOLD_SECS`| `3`                                            | Idle must drop below this to count as "woke up" |
| `LOG_FILE`           | `~/.local/share/idle-power-manager.log`        | Log file path                                   |

### Dependencies

| Dependency | Notes |
|------------|-------|
| `gdbus` | DBus CLI tool from the `glib2` package — usually pre-installed on GNOME |
| `tuned` | Must be installed and the system service running |
| `tuned-adm` | CLI for tuned, part of the `tuned` package |
| polkit / `wheel` group | Profile switching calls tuned via system DBus; polkit grants access to `wheel` group members without sudo |
| GNOME session (Wayland) | Idle time is read from `org.gnome.Mutter.IdleMonitor` |

Install and enable tuned if not present:

```sh
sudo dnf install tuned        # Fedora/RHEL
sudo systemctl enable --now tuned
```

Verify your user is in the `wheel` group:

```sh
groups $USER   # should include 'wheel'
```

### Install as a systemd user service

The service starts automatically after login when the GNOME graphical session is ready.

**1. Copy the script** to `~/bin/` (or adjust `ExecStart` to your preferred path):

```sh
cp idle-power-manager.sh ~/bin/
chmod +x ~/bin/idle-power-manager.sh
```

**2. Create the service file** at `~/.config/systemd/user/idle-power-manager.service`:

```ini
[Unit]
Description=Idle Power Manager - switch to powersave on inactivity
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=%h/bin/idle-power-manager.sh
Restart=on-failure
RestartSec=10s
Environment="IDLE_THRESHOLD_MINS=15"
Environment="IDLE_PROFILE=powersave"
Environment="CHECK_INTERVAL=30"
Environment="WAKE_THRESHOLD_SECS=3"

[Install]
WantedBy=graphical-session.target
```

**3. Enable and start:**

```sh
systemctl --user daemon-reload
systemctl --user enable --now idle-power-manager.service
```

**4. Check status / logs:**

```sh
systemctl --user status idle-power-manager.service
journalctl --user -u idle-power-manager.service -f
```

### Overriding settings without editing the service file

```sh
systemctl --user edit idle-power-manager.service
```

Add an override section, for example:

```ini
[Service]
Environment="IDLE_THRESHOLD_MINS=20"
```

Then reload: `systemctl --user daemon-reload && systemctl --user restart idle-power-manager.service`

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
