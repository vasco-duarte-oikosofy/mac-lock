#!/usr/bin/env bash
#
# mac-lock.sh — watches the lid angle sensor and locks the screen once the
# lid is down to 10% of its fully-open angle (i.e. nearly closed). Triggering
# a bit before full closure — rather than waiting for AppleClamshellState to
# flip, which happens right as the lid bottoms out — gives the lock command
# a brief head start on macOS's "clamshell sleep" transition instead of
# racing it at the very last instant.
#
# Requires ./lidangle (compiled from lidangle.swift: `swiftc -O lidangle.swift -o lidangle`)
# and ./locker (compiled from locker.swift: `swiftc -O locker.swift -o locker`)
# Only works on Macs with a lid angle sensor (MacBook Pro 16" 2019+, M-series
# MacBook Pro/Air from ~2021+).
#
# Usage: ./mac-lock.sh [poll_interval_seconds] [remaining_open_fraction]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIDANGLE="$SCRIPT_DIR/lidangle"
LOCKER="$SCRIPT_DIR/locker"

POLL_INTERVAL="${1:-0.2}"
CLOSE_FRACTION="${2:-0.10}"   # trigger once the lid has closed down to this fraction of baseline remaining
REOPEN_FRACTION="0.20"        # must reopen past this fraction of baseline to re-arm

if [ ! -x "$LIDANGLE" ]; then
    echo "error: $LIDANGLE not found or not executable. Build it with: swiftc -O lidangle.swift -o lidangle" >&2
    exit 1
fi

if [ ! -x "$LOCKER" ]; then
    echo "error: $LOCKER not found or not executable. Build it with: swiftc -O locker.swift -o locker" >&2
    exit 1
fi

lock_screen() {
    local t0 t1 err rc
    t0=$(date '+%s.%N')
    err="$("$LOCKER" 2>&1)"
    rc=$?
    t1=$(date '+%s.%N')
    echo "$(date '+%H:%M:%S')  lock_screen: locker rc=$rc elapsed=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')s${err:+ stderr=\"$err\"}"
}

baseline=0
triggered=false

while true; do
    angle="$($LIDANGLE 2>/dev/null)"

    if [ -n "$angle" ] && [ "$angle" -gt 0 ] 2>/dev/null; then
        if [ "$angle" -gt "$baseline" ]; then
            baseline=$angle
        fi

        if [ "$baseline" -gt 0 ]; then
            close_threshold=$(awk -v b="$baseline" -v f="$CLOSE_FRACTION" 'BEGIN { printf "%d", b * f }')
            reopen_threshold=$(awk -v b="$baseline" -v f="$REOPEN_FRACTION" 'BEGIN { printf "%d", b * f }')

            if [ "$angle" -le "$close_threshold" ] && [ "$triggered" = false ]; then
                echo "$(date '+%H:%M:%S')  angle=$angle baseline=$baseline -> down to ${CLOSE_FRACTION} of baseline, locking"
                lock_screen
                triggered=true
            elif [ "$angle" -ge "$reopen_threshold" ]; then
                triggered=false
            fi
        fi
    fi

    sleep "$POLL_INTERVAL"
done
