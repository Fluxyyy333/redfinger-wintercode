#!/data/data/com.termux/files/usr/bin/bash
# Zwatchdog.sh — Light Memory Guardian v4
# 300s interval — only re-enforces what actually drifts between boots
# Run in background: nohup bash Zwatchdog.sh >> ~/Zwatchdog.log 2>&1 &

INTERVAL=300
LOW_MEM_THRESHOLD=200
CRIT_MEM_THRESHOLD=100
LOG="$HOME/Zwatchdog.log"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

echo "$$" > "$HOME/.watchdog.pid"

if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 2000 ]; then
    tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log "[watchdog] started v4 (interval=${INTERVAL}s pid=$$)"

# Only packages that genuinely auto-restart on Redfinger
RESPAWN_PKGS=(
    com.android.vending
    com.android.phone
    com.baidu.cloud.service
    com.wshl.file.observerservice
)

CYCLE=0

while true; do
    FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
    CYCLE=$((CYCLE + 1))

    # ── Force-stop auto-respawning bloat ──────────────────────
    FSTOP_CMD=""
    for pkg in "${RESPAWN_PKGS[@]}"; do
        FSTOP_CMD="${FSTOP_CMD}am force-stop $pkg; "
    done
    su -c "$FSTOP_CMD" 2>/dev/null

    # ── Re-enforce OOM scores (PIDs change after crash) ───────
    OOM_CMD=""
    TERMUX_PIDS=$(su -c "pidof com.termux" 2>/dev/null)
    for pid in $TERMUX_PIDS; do
        [ -n "$pid" ] && OOM_CMD="${OOM_CMD}echo -400 > /proc/$pid/oom_score_adj; "
    done
    LUA_PID=$(pgrep -n lua 2>/dev/null)
    [ -n "$LUA_PID" ] && OOM_CMD="${OOM_CMD}echo -300 > /proc/$LUA_PID/oom_score_adj; "
    GAME_PIDS=$(su -c "ps -A 2>/dev/null | grep -E 'com\.fluxy|com\.delt|com\.roblox' | awk '{print \$2}'")
    GAME_COUNT=0
    for pid in $GAME_PIDS; do
        [ -n "$pid" ] && OOM_CMD="${OOM_CMD}echo -200 > /proc/$pid/oom_score_adj; " && GAME_COUNT=$((GAME_COUNT + 1))
    done
    [ -n "$OOM_CMD" ] && su -c "$OOM_CMD" 2>/dev/null

    # ── LOW MEMORY: trim GMS + cleanup ────────────────────────
    if [ "$FREE_MB" -lt "$LOW_MEM_THRESHOLD" ]; then
        log "[watchdog] LOW: ${FREE_MB}MB — trimming"
        su -c "am send-trim-memory com.google.android.gms COMPLETE; am send-trim-memory com.google.android.gms.persistent COMPLETE" 2>/dev/null
        su -c "rm -rf /data/tombstones/* /data/anr/*" 2>/dev/null
    fi

    # ── CRITICAL: emergency force-stop GMS ────────────────────
    if [ "$FREE_MB" -lt "$CRIT_MEM_THRESHOLD" ]; then
        log "[watchdog] CRITICAL: ${FREE_MB}MB — emergency"
        su -c "am force-stop com.google.android.gms; am send-trim-memory system RUNNING_CRITICAL; pm trim-caches 500M" 2>/dev/null
    fi

    # ── Status log every 2 cycles (10 min) ────────────────────
    if [ $((CYCLE % 2)) -eq 0 ]; then
        SWAP_FREE=$(( $(grep SwapFree /proc/meminfo | awk '{print $2}') / 1024 ))
        log "[watchdog] RAM:${FREE_MB}MB Swap:${SWAP_FREE}MB Game:${GAME_COUNT} cycle:${CYCLE}"
    fi

    # ── Log rotation ──────────────────────────────────────────
    if [ $((CYCLE % 30)) -eq 0 ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 2000 ]; then
        tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi

    sleep $INTERVAL
done
