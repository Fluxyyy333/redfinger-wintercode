#!/data/data/com.termux/files/usr/bin/bash
# Zwatchdog.sh — Aggressive Memory Management Daemon v3
# Redfinger Android 10 ARM64 | Target: 8 Roblox instances on 4GB RAM
# Run in background: nohup bash Zwatchdog.sh >> ~/Zwatchdog.log 2>&1 &

INTERVAL=60
LOW_MEM_THRESHOLD=200
CRIT_MEM_THRESHOLD=100
LOG="$HOME/Zwatchdog.log"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

# Write PID file for self-heal monitoring
echo "$$" > "$HOME/.watchdog.pid"

# Log rotation: keep last 500 lines
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 2000 ]; then
    tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

log "[watchdog] started v3 (interval=${INTERVAL}s low=${LOW_MEM_THRESHOLD}MB crit=${CRIT_MEM_THRESHOLD}MB pid=$$)"

BLOAT_KILL_LIST=(
    "com.android.vending"
    "com.google.android.apps.nbu.files"
    "com.google.android.inputmethod.latin"
    "com.google.android.play.games"
    "com.android.inputmethod.latin"
    "com.android.phone"
    "com.android.server.telecom"
    "com.android.dialer"
    "com.android.bluetooth"
    "com.android.contacts"
    "com.wsh.appstore"
    "com.android.email"
    "com.android.messaging"
    "com.android.calendar"
    "com.android.chrome"
    "com.baidu.cloud.service"
    "com.wshl.file.observerservice"
    "com.android.launcher3"
    "com.android.settings"
    "com.android.documentsui"
    "com.google.android.tts"
    "com.android.keychain"
    "com.google.android.setupwizard"
    "com.google.android.gsf.login"
    "com.android.nfc"
    "com.android.providers.downloads"
)

PERSISTENT_KILL=(
    "com.android.plugin"
    "com.android.se"
    "com.android.datatransport"
    "android.process.media"
)

CYCLE=0

while true; do
    FREE_MB=$(( $(grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024 ))
    CYCLE=$((CYCLE + 1))

    # ── Force-stop bloat that auto-restarts (batched) ────────────
    FSTOP_CMD=""
    for pkg in "${BLOAT_KILL_LIST[@]}"; do
        FSTOP_CMD="${FSTOP_CMD}am force-stop $pkg; "
    done
    su -c "$FSTOP_CMD" 2>/dev/null

    # ── Kill persistent processes (they ignore pm disable) ────
    for P in "${PERSISTENT_KILL[@]}"; do
        PID=$(su -c "pidof $P" 2>/dev/null)
        if [ -n "$PID" ]; then
            su -c "echo 1000 > /proc/$PID/oom_score_adj; kill -9 $PID" 2>/dev/null
        fi
    done

    # ── Re-enforce AM constants (reset on some events) ────────
    su -c "settings put global activity_manager_constants max_cached_processes=4,background_settle_time=5000,fgs_bg_restriction_enabled=true; settings put global always_finish_activities 0" 2>/dev/null

    # ── Drop filesystem caches ────────────────────────────────
    su -c "echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null

    # ── Protect OOM scores: Termux/Lua/Roblox (batched) ───────
    TERMUX_PIDS=$(su -c "pidof com.termux" 2>/dev/null)
    OOM_CMD=""
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

    # ── Demote bloat processes OOM + priority ──────────────────
    DEMOTE_CMD=""
    for P in com.google.process.gservices com.google.process.gapps com.android.phone com.android.keychain; do
        PID=$(su -c "pidof $P" 2>/dev/null)
        if [ -n "$PID" ]; then
            DEMOTE_CMD="${DEMOTE_CMD}echo 1000 > /proc/$PID/oom_score_adj; "
            renice 19 -p $PID 2>/dev/null
        fi
    done
    [ -n "$DEMOTE_CMD" ] && su -c "$DEMOTE_CMD" 2>/dev/null

    # ── GMS memory trim ───────────────────────────────────────
    su -c "am send-trim-memory com.google.android.gms COMPLETE; am send-trim-memory com.google.android.gms.persistent COMPLETE; am send-trim-memory com.google.process.gservices COMPLETE; am send-trim-memory com.google.process.gapps COMPLETE" 2>/dev/null

    # ── Kill zombie processes ─────────────────────────────────
    ZOMBIES=$(su -c "ps -A 2>/dev/null" | awk '$4=="Z" || $5=="Z" {print $2}')
    for zpid in $ZOMBIES; do
        su -c "kill -9 $zpid" 2>/dev/null
    done

    # ── LOW MEMORY: aggressive trim ────────────────────────────
    if [ $FREE_MB -lt $LOW_MEM_THRESHOLD ]; then
        log "[watchdog] LOW: ${FREE_MB}MB — trimming"
        su -c "am send-trim-memory system RUNNING_CRITICAL; rm -rf /data/tombstones/* /data/anr/*; pm trim-caches 500M" 2>/dev/null
        for P in "${PERSISTENT_KILL[@]}"; do
            PID=$(su -c "pidof $P" 2>/dev/null)
            [ -n "$PID" ] && su -c "kill -9 $PID" 2>/dev/null
        done
    fi

    # ── CRITICAL MEMORY: emergency ─────────────────────────────
    if [ $FREE_MB -lt $CRIT_MEM_THRESHOLD ]; then
        log "[watchdog] CRITICAL: ${FREE_MB}MB — emergency"
        RUNNING=$(su -c "ps -A 2>/dev/null" | grep -vE 'com\.fluxy|com\.delt|com\.roblox|com\.termux|system_server|zygote|servicemanager|surfaceflinger|vold|logd|adbd|lua' | awk 'NR>1{print $NF}' | sort -u)
        for proc in $RUNNING; do
            su -c "am send-trim-memory $proc COMPLETE" 2>/dev/null
        done
        su -c "am force-stop com.google.android.gms" 2>/dev/null
    fi

    # ── Log status (every 5 cycles = 5 min to reduce log spam) ─
    if [ $((CYCLE % 5)) -eq 0 ]; then
        SWAP_FREE=$(( $(grep SwapFree /proc/meminfo | awk '{print $2}') / 1024 ))
        log "[watchdog] RAM:${FREE_MB}MB Swap:${SWAP_FREE}MB Game:${GAME_COUNT} cycle:${CYCLE}"
    fi

    # ── Log rotation mid-run ───────────────────────────────────
    if [ $((CYCLE % 60)) -eq 0 ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 2000 ]; then
        tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi

    sleep $INTERVAL
done
