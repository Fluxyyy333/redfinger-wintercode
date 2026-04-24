#!/data/data/com.termux/files/usr/bin/bash
# Zwatchdog.sh — Aggressive Memory Management Daemon v2
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# Run in background: nohup bash Zwatchdog.sh >> ~/Zwatchdog.log 2>&1 &

INTERVAL=60
LOW_MEM_THRESHOLD=200
CRIT_MEM_THRESHOLD=100
LOG="$HOME/Zwatchdog.log"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }
log "[watchdog] started v2 (interval=${INTERVAL}s low=${LOW_MEM_THRESHOLD}MB crit=${CRIT_MEM_THRESHOLD}MB)"

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
    "com.android.keychain"
)

PERSISTENT_KILL=(
    "com.android.systemui"
    "com.android.plugin"
    "com.android.se"
    "com.android.datatransport"
    "android.process.media"
)

while true; do
    FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))

    # ── Force-stop bloat that auto-restarts ───────────────────
    for pkg in "${BLOAT_KILL_LIST[@]}"; do
        su -c "am force-stop $pkg" 2>/dev/null
    done

    # ── Kill persistent processes (they ignore pm disable) ────
    for P in "${PERSISTENT_KILL[@]}"; do
        PID=$(su -c "pidof $P" 2>/dev/null)
        if [ -n "$PID" ]; then
            su -c "echo 1000 > /proc/$PID/oom_score_adj" 2>/dev/null
            su -c "kill -9 $PID" 2>/dev/null
        fi
    done

    # ── Re-enforce AM constants (reset on some events) ────────
    su -c "settings put global activity_manager_constants max_cached_processes=2,background_settle_time=5000,fgs_bg_restriction_enabled=true" 2>/dev/null
    su -c "settings put global always_finish_activities 1" 2>/dev/null

    # ── Drop filesystem caches ────────────────────────────────
    su -c "echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null

    # ── Protect OOM scores: Termux/Lua/Roblox ─────────────────
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

    # ── Demote bloat processes OOM + priority ──────────────────
    for P in com.google.process.gservices com.google.process.gapps com.android.phone com.android.keychain; do
        PID=$(su -c "pidof $P" 2>/dev/null)
        if [ -n "$PID" ]; then
            su -c "echo 1000 > /proc/$PID/oom_score_adj" 2>/dev/null
            renice 19 -p $PID 2>/dev/null
        fi
    done

    # ── GMS memory trim ───────────────────────────────────────
    su -c "am send-trim-memory com.google.android.gms COMPLETE" 2>/dev/null
    su -c "am send-trim-memory com.google.android.gms.persistent COMPLETE" 2>/dev/null
    su -c "am send-trim-memory com.google.process.gservices COMPLETE" 2>/dev/null
    su -c "am send-trim-memory com.google.process.gapps COMPLETE" 2>/dev/null

    # ── Kill zombie processes ─────────────────────────────────
    ZOMBIES=$(su -c "ps -A 2>/dev/null | awk '\$4==\"Z\" {print \$2}'")
    for zpid in $ZOMBIES; do
        su -c "kill -9 $zpid" 2>/dev/null
    done

    # ── Cancel scheduled jobs ──────────────────────────────────
    su -c "cmd jobscheduler cancel-all" 2>/dev/null

    # ── LOW MEMORY: aggressive trim ────────────────────────────
    if [ $FREE_MB -lt $LOW_MEM_THRESHOLD ]; then
        log "[watchdog] LOW: ${FREE_MB}MB — trimming"
        su -c "am send-trim-memory system RUNNING_CRITICAL" 2>/dev/null
        su -c "rm -rf /data/tombstones/* /data/anr/*" 2>/dev/null
        su -c "pm trim-caches 999G" 2>/dev/null
        for P in "${PERSISTENT_KILL[@]}"; do
            PID=$(su -c "pidof $P" 2>/dev/null)
            [ -n "$PID" ] && su -c "kill -9 $PID" 2>/dev/null
        done
    fi

    # ── CRITICAL MEMORY: emergency ─────────────────────────────
    if [ $FREE_MB -lt $CRIT_MEM_THRESHOLD ]; then
        log "[watchdog] CRITICAL: ${FREE_MB}MB — emergency"
        RUNNING=$(su -c "ps -A 2>/dev/null" | grep -vE 'com\.fluxy|com\.deltb|com\.roblox|com\.termux|system_server|zygote|servicemanager|surfaceflinger|vold|logd|adbd|lua' | awk 'NR>1{print $NF}' | sort -u)
        for proc in $RUNNING; do
            su -c "am send-trim-memory $proc COMPLETE" 2>/dev/null
        done
        su -c "am force-stop com.google.android.gms" 2>/dev/null
    fi

    # ── Log status ─────────────────────────────────────────────
    SWAP_FREE=$(( $(grep SwapFree /proc/meminfo | awk '{print $2}') / 1024 ))
    log "[watchdog] RAM:${FREE_MB}MB Swap:${SWAP_FREE}MB Game:${GAME_COUNT}"

    sleep $INTERVAL
done
