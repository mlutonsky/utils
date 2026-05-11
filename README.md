# utils

A collection of small shell utilities.

## Scripts

| Script | Description |
|--------|-------------|
| [git-co](#git-co) | Fuzzy-matching git branch checkout with typo correction and interactive selection |
| [git-branch-clean](#git-branch-clean) | Prune stale remote refs and delete local branches whose remote is gone |
| [git-branch-close](#git-branch-close) | Fast-forward merge current branch into default branch, push, and delete it |
| [git-commit-msg](#git-commit-msg) | Generate a commit message from staged (or unstaged) changes using Claude |
| [idle-power-manager.sh](#idle-power-managersh) | Automatic CPU power profile switcher based on GNOME idle detection |

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

**Prune stale remote refs and delete local branches whose remote is gone.**

Runs `git fetch --prune`, then deletes every local branch that tracked a remote
branch which no longer exists. Safe to run routinely after merging or closing
feature branches.

### Usage

```
git-branch-clean [-h|--help]
```

### Example

```sh
$ git-branch-clean
Fetching and pruning...
Deleted branch feature/login (was abc1234).
Deleted branch fix/typo (was def5678).
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
configurable idle timeout and restores the performance profile as soon as
activity is detected. The performance profile is auto-detected from the active
tuned profile at startup.

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
| `PERFORMANCE_PROFILE`| auto-detected from current tuned profile       | Profile to restore when activity is detected    |
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
