# utils

A collection of small shell utilities.

## Scripts

| Script | Description |
|--------|-------------|
| [git-co](#git-co) | Fuzzy-matching git branch checkout with typo correction and interactive selection |
| [git-branch-clean](#git-branch-clean) | Prune stale remote refs and delete obsolete local branches (upstream gone, or untracked-and-merged) |
| [git-branch-close](#git-branch-close) | Fast-forward merge current branch into default branch, push, and delete it |
| [git-commit-msg](#git-commit-msg) | Generate a commit message from staged (or unstaged) changes using Claude |
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
