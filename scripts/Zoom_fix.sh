#!/data/data/com.termux/files/usr/bin/bash
# Zoom_fix.sh — Override WinterHub's oom_score_adj=-1000
# WinterHub sets all Delta clones to oom=-1000 (unkillable), preventing
# Android from trimming memory. This causes RAM bloat and MORE crashes.
# We reset to oom=0 so Android can manage memory naturally.
# Runs as background daemon, re-applies every 60s (WinterHub may re-set on rejoin)

LOG="$HOME/Zoom_fix.log"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

log "[oom_fix] daemon started"

while true; do
    FIXED=0
    for pkg in $(su -c "pm list packages 2>/dev/null" | grep -oE 'com\.delt[a-z]+'); do
        pid=$(pidof "$pkg" 2>/dev/null)
        [ -z "$pid" ] && continue

        current=$(cat /proc/$pid/oom_score_adj 2>/dev/null)
        if [ "$current" = "-1000" ]; then
            echo 0 > /proc/$pid/oom_score_adj 2>/dev/null
            FIXED=$((FIXED + 1))
        fi
    done

    [ "$FIXED" -gt 0 ] && log "[oom_fix] reset $FIXED clone(s) from -1000 to 0"

    sleep 60
done
