# utils

A collection of small shell utilities.

## Scripts

| Script | Description |
|--------|-------------|
| [git-co](#git-co) | Fuzzy-matching git branch checkout with typo correction and interactive selection |
| [idle-power-manager.sh](#idle-power-managersh) | Automatic CPU power profile switcher based on GNOME idle detection |

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

## idle-power-manager.sh

**Automatic CPU power profile switcher based on idle detection.**

Monitors user activity via GNOME Mutter DBus (Wayland-native, no sudo needed).
Switches to a powersave [tuned](https://tuned-project.org/) profile after a
configurable idle timeout and restores the performance profile as soon as
activity is detected. The performance profile is auto-detected from the active
tuned profile at startup.

**Requirements:** `gdbus`, `tuned`, `tuned-adm`, GNOME session (Wayland)

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
