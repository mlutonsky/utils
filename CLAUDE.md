# CLAUDE.md — utils repo

This repository is a personal collection of small, focused shell utilities.
Each script is standalone, self-documenting, and follows a consistent style.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `git-co` | Fuzzy-matching git branch checkout |
| `git-branch-clean` | Delete local branches whose upstream is gone, or that have no upstream and are merged into the integration branch |
| `git-branch-close` | FF-merge current branch into default, push, delete |
| `git-commit-msg` | Generate a commit message from staged/unstaged changes using Claude |
| `git-changelog` | Draft the next CHANGELOG entry + version bump (patch/minor) using Claude; optionally commit, tag, and push the release |
| `idle-power-manager.sh` | Switch CPU tuned profile on GNOME idle/wake |
| `neon2json` | Convert NEON (Nette Object Notation) to JSON, from file or stdin |
| `install.sh` | Install all scripts to ~/.local/bin via symlinks |

---

## Script conventions

Every script must follow these conventions:

### Header comment block

Lines 2–N are `#`-prefixed comments that serve as both source documentation and
the output of `--help`. The `_print_help` function extracts them verbatim, so
they must be complete and accurate.

Required sections (in order):

```
#!/bin/bash
# <script-name> — <one-line description>
#
# <paragraph describing what it does and how>
#
# Usage:
#   <script-name> [options]
#
# Examples:
#   <script-name> <args>    # comment
```

Add optional sections as needed: `Requirements:`, `Configuration:`, etc.

### Help flag

Every script must support `-h` and `--help` and print the header block:

```bash
_print_help() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

case "$1" in
  -h|--help) _print_help; exit 0 ;;
esac
```

### Error messages

Use `fatal:` prefix for fatal errors (mirrors git style):

```bash
echo "fatal: not a git repository"
exit 1
```

### Git commands

Prefer `git switch` over `git checkout` for branch operations.

---

## Adding a new script

1. **Write the script** following the conventions above (header, `_print_help`, `-h`/`--help`, `fatal:` errors).
2. **Make it executable:** `chmod +x <script-name>`
3. **Update `README.md`:**
   - Add a row to the index table at the top.
   - Add a full section (`##`) with description, usage, example output, and install one-liner.
4. **Update `CLAUDE.md`:** add a row to the Scripts table above.
5. **Add a symlink entry to `install.sh`:** append the script name to the `SCRIPTS` array.
