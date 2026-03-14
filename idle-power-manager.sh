#!/bin/bash
# idle-power-manager.sh — automatic CPU power profile manager based on idle detection
#
# Monitors user activity via GNOME Mutter DBus (Wayland-native, no sudo needed).
# Switches to a powersave tuned profile after a configurable idle timeout and
# restores the performance profile as soon as activity is detected.
# Performance profile is auto-detected at startup from the current tuned profile.
#
# Requirements:
#   gdbus       - DBus CLI tool (glib2 package, usually pre-installed on GNOME)
#   tuned       - system service must be installed and running (dnf install tuned)
#   tuned-adm   - CLI for tuned, part of the tuned package
#   polkit      - profile switching uses tuned's system DBus interface; user must
#                 be in the 'wheel' group for polkit to allow it without sudo
#   GNOME session (Wayland) - idle time is read from org.gnome.Mutter.IdleMonitor
#
# Usage:
#   idle-power-manager.sh [-h|--help]
#   IDLE_THRESHOLD_MINS=20 idle-power-manager.sh
#
# Configuration (environment variables):
#   IDLE_THRESHOLD_MINS  - minutes of inactivity before switching to idle profile (default: 15)
#   PERFORMANCE_PROFILE  - tuned profile to restore on activity (default: auto-detected)
#   IDLE_PROFILE         - tuned profile to use when idle (default: powersave)
#   CHECK_INTERVAL       - seconds between idle checks (default: 30)
#   WAKE_THRESHOLD_SECS  - idle must drop below this to count as "woke up" (default: 3)
#   LOG_FILE             - log file path (default: ~/.local/share/idle-power-manager.log)
#   MAX_LOG_LINES        - maximum number of lines to keep in the log file (default: 10000)
#
# Examples:
#   idle-power-manager.sh                          # run with defaults
#   IDLE_THRESHOLD_MINS=20 idle-power-manager.sh   # switch after 20 min idle
#   PERFORMANCE_PROFILE=latency-performance \
#     IDLE_PROFILE=powersave idle-power-manager.sh  # explicit profiles
#
# To run as a systemd user service, create:
#   ~/.config/systemd/user/idle-power-manager.service
# and set: ExecStart=/path/to/idle-power-manager.sh

_print_help() {
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

case "$1" in
    -h|--help) _print_help; exit 0 ;;
esac

IDLE_THRESHOLD_MINS="${IDLE_THRESHOLD_MINS:-15}"
IDLE_PROFILE="${IDLE_PROFILE:-powersave}"
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
WAKE_THRESHOLD_SECS="${WAKE_THRESHOLD_SECS:-3}"
LOG_FILE="${LOG_FILE:-$HOME/.local/share/idle-power-manager.log}"
MAX_LOG_LINES="${MAX_LOG_LINES:-10000}"

IDLE_THRESHOLD_MS=$(( IDLE_THRESHOLD_MINS * 60 * 1000 ))
WAKE_THRESHOLD_MS=$(( WAKE_THRESHOLD_SECS * 1000 ))

# --- Logging ---
log() {
    local level="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE" >&2
}

# --- Log rotation ---
rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local line_count
        line_count=$(wc -l < "$LOG_FILE")
        if (( line_count > MAX_LOG_LINES )); then
            local tmp
            tmp=$(mktemp)
            if tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp"; then
                mv "$tmp" "$LOG_FILE" || rm -f "$tmp"
            else
                rm -f "$tmp"
            fi
        fi
    fi
}

# --- Detect current performance profile at startup (save it for restoration) ---
get_current_profile() {
    tuned-adm active 2>/dev/null | grep -oP '(?<=Current active profile: ).*'
}

# --- Switch tuned profile via DBus (polkit allows wheel group, no sudo needed) ---
switch_profile() {
    local profile="$1"
    if gdbus call --system \
        --dest com.redhat.tuned \
        --object-path /Tuned \
        --method com.redhat.tuned.control.switch_profile \
        "$profile" > /dev/null 2>&1; then
        return 0
    else
        log "ERROR" "Failed to switch to profile '$profile'"
        return 1
    fi
}

# --- Get idle time in milliseconds from GNOME Mutter ---
get_idle_ms() {
    gdbus call \
        --session \
        --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime \
        2>/dev/null | grep -oP 'uint64 \K\d+'
}

# --- Wait for GNOME session DBus to be ready ---
wait_for_session_bus() {
    local retries=30
    while (( retries-- > 0 )); do
        if get_idle_ms > /dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    log "ERROR" "GNOME session DBus not available after 60s. Is GNOME running?"
    return 1
}

# --- Main ---
mkdir -p "$(dirname "$LOG_FILE")"

log "INFO" "Starting idle-power-manager (threshold: ${IDLE_THRESHOLD_MINS}m, check every: ${CHECK_INTERVAL}s)"

# Auto-detect performance profile: use current profile at startup (unless it's already powersave)
PERFORMANCE_PROFILE="${PERFORMANCE_PROFILE:-}"
if [[ -z "$PERFORMANCE_PROFILE" ]]; then
    startup_profile=$(get_current_profile)
    if [[ "$startup_profile" == "$IDLE_PROFILE" ]]; then
        # Was left in powersave from a previous run, use a sane default
        PERFORMANCE_PROFILE="throughput-performance"
        log "WARN" "System was already in idle profile at startup, defaulting performance profile to: $PERFORMANCE_PROFILE"
    else
        PERFORMANCE_PROFILE="$startup_profile"
    fi
fi
log "INFO" "Performance profile: $PERFORMANCE_PROFILE | Idle profile: $IDLE_PROFILE"

wait_for_session_bus || exit 1

rotate_log

state="active"  # "active" or "idle"

while true; do
    idle_ms=$(get_idle_ms)

    if [[ -z "$idle_ms" ]]; then
        log "WARN" "Could not read idle time, retrying in ${CHECK_INTERVAL}s"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    idle_secs=$(( idle_ms / 1000 ))

    if [[ "$state" == "active" ]] && (( idle_ms >= IDLE_THRESHOLD_MS )); then
        idle_mins=$(( idle_secs / 60 ))
        log "INFO" "Idle for ${idle_mins}m ${idle_secs}s — switching to $IDLE_PROFILE"
        if switch_profile "$IDLE_PROFILE"; then
            log "INFO" "Switched to $IDLE_PROFILE"
            state="idle"
        fi

    elif [[ "$state" == "idle" ]] && (( idle_ms < WAKE_THRESHOLD_MS )); then
        log "INFO" "User activity detected (idle dropped to ${idle_secs}s) — restoring $PERFORMANCE_PROFILE"
        if switch_profile "$PERFORMANCE_PROFILE"; then
            log "INFO" "Restored to $PERFORMANCE_PROFILE"
            state="active"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
