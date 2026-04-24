#!/data/data/com.termux/files/usr/bin/bash
# Zwatchdog.sh — Active Memory Management Daemon
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# Run in background: nohup bash Zwatchdog.sh >> ~/Zwatchdog.log 2>&1 &

INTERVAL=60
LOW_MEM_THRESHOLD=200
CRIT_MEM_THRESHOLD=100
LOG="$HOME/Zwatchdog.log"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }
log "[watchdog] started (interval=${INTERVAL}s low=${LOW_MEM_THRESHOLD}MB crit=${CRIT_MEM_THRESHOLD}MB)"

BLOAT_KILL_LIST=(
    "com.android.vending"
    "com.google.android.apps.nbu.files"
    "com.google.android.inputmethod.latin"
    "com.google.android.play.games"
    "com.android.inputmethod.latin"
    "com.android.phone"
    "com.wsh.appstore"
    "com.android.email"
    "com.android.messaging"
    "com.android.calendar"
    "com.android.chrome"
    "com.baidu.cloud.service"
    "com.wshl.file.observerservice"
    "com.android.systemui"
    "com.android.launcher3"
    "com.wsh.launcher"
    "com.android.settings"
    "com.google.android.tts"
)

while true; do
    FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))

    # ── Periodic: kill bloat that auto-restarted ───────────────
    for pkg in "${BLOAT_KILL_LIST[@]}"; do
        su -c "am force-stop $pkg" 2>/dev/null
    done

    # ── Periodic: drop filesystem caches ───────────────────────
    su -c "echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null

    # ── Periodic: re-protect OOM scores ────────────────────────
    TERMUX_PIDS=$(su -c "pidof com.termux" 2>/dev/null)
    for pid in $TERMUX_PIDS; do
        [ -n "$pid" ] && su -c "echo -400 > /proc/$pid/oom_score_adj" 2>/dev/null
    done
    LUA_PID=$(pgrep -n lua 2>/dev/null)
    [ -n "$LUA_PID" ] && su -c "echo -300 > /proc/$LUA_PID/oom_score_adj" 2>/dev/null

    GAME_PIDS=$(su -c "ps -A 2>/dev/null | grep -E 'com\.fluxy|com\.deltb|com\.roblox' | awk '{print \$2}'")
    GAME_COUNT=0
    for pid in $GAME_PIDS; do
        [ -n "$pid" ] && su -c "echo -200 > /proc/$pid/oom_score_adj" 2>/dev/null && GAME_COUNT=$((GAME_COUNT + 1))
    done

    # ── Periodic: trim GMS memory ──────────────────────────────
    su -c "am send-trim-memory com.google.android.gms RUNNING_LOW" 2>/dev/null

    # ── Kill zombie processes ──────────────────────────────────
    ZOMBIES=$(su -c "ps -A 2>/dev/null | awk '\$4==\"Z\" {print \$2}'")
    for zpid in $ZOMBIES; do
        su -c "kill -9 $zpid" 2>/dev/null
    done

    # ── LOW MEMORY: aggressive trim ────────────────────────────
    if [ $FREE_MB -lt $LOW_MEM_THRESHOLD ]; then
        log "[watchdog] LOW: ${FREE_MB}MB — trimming system+GMS"
        su -c "am send-trim-memory system RUNNING_CRITICAL" 2>/dev/null
        su -c "am send-trim-memory com.google.android.gms RUNNING_CRITICAL" 2>/dev/null
        su -c "rm -rf /data/tombstones/*" 2>/dev/null
        su -c "cmd jobscheduler cancel-all" 2>/dev/null
    fi

    # ── CRITICAL MEMORY: emergency ─────────────────────────────
    if [ $FREE_MB -lt $CRIT_MEM_THRESHOLD ]; then
        log "[watchdog] CRITICAL: ${FREE_MB}MB — emergency trim all"
        RUNNING=$(su -c "ps -A 2>/dev/null" | grep -vE 'com\.fluxy|com\.deltb|com\.roblox|com\.termux|system_server|com\.google\.android\.gms|zygote|servicemanager|surfaceflinger|vold|logd|adbd' | awk '{print $NF}' | sort -u)
        for proc in $RUNNING; do
            su -c "am send-trim-memory $proc COMPLETE" 2>/dev/null
        done
    fi

    # ── Log status every cycle ─────────────────────────────────
    SWAP_FREE=$(( $(grep SwapFree /proc/meminfo | awk '{print $2}') / 1024 ))
    log "[watchdog] RAM:${FREE_MB}MB Swap:${SWAP_FREE}MB Game:${GAME_COUNT}"

    sleep $INTERVAL
done
